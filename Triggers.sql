set search_path to greencoin;

--1. Auto-update the LastUpdateDate whenever a GovernmentPolicy row is modified.
CREATE OR REPLACE FUNCTION update_policy_last_modified()
RETURNS TRIGGER AS $$
BEGIN
    NEW.LastUpdateDate := CURRENT_DATE;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_policy_update
BEFORE UPDATE ON GovernmentPolicy
FOR EACH ROW
EXECUTE PROCEDURE update_policy_last_modified();

--2 Update Buyer and Seller credits after transaction
CREATE OR REPLACE FUNCTION update_credit_on_transaction()
RETURNS TRIGGER AS $$
BEGIN
    -- Update seller's CSell
    UPDATE Credit
    SET CSell = COALESCE(CSell, 0) + NEW.CreditsTraded
    WHERE RegNo = NEW.SellerRegNo
      AND CreditAllocatedYear = EXTRACT(YEAR FROM NEW.TDate);

    -- Update buyer's CBuy
    UPDATE Credit
    SET CBuy = COALESCE(CBuy, 0) + NEW.CreditsTraded
    WHERE RegNo = NEW.BuyerRegNo
      AND CreditAllocatedYear = EXTRACT(YEAR FROM NEW.TDate);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_credit_after_transaction
AFTER INSERT ON "Transaction"
FOR EACH ROW
EXECUTE PROCEDURE update_credit_on_transaction();

--3 Update CProduced when branchCredits are changes
CREATE OR REPLACE FUNCTION update_cproduced_from_branch()
RETURNS TRIGGER AS $$
BEGIN
    -- Update the CProduced value in Credit table
    UPDATE Credit
    SET CProduced = (
        SELECT COALESCE(SUM(BranchCredits), 0)
        FROM Branch
        WHERE RegNo = NEW.RegNo AND "Year" = NEW."Year"
    )
    WHERE RegNo = NEW.RegNo AND CreditAllocatedYear = NEW."Year";

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_cproduced_insert
AFTER INSERT OR UPDATE OR DELETE ON Branch
FOR EACH ROW
EXECUTE PROCEDURE update_cproduced_from_branch();


--4 Update EquivalentTonnes when branchCredits are changed
CREATE OR REPLACE FUNCTION update_equivalent_emission_on_credit_increase()
RETURNS TRIGGER AS $$
DECLARE
    total_equivalent_emission DECIMAL(10,2);
    gas_record RECORD;
    emission_increase DECIMAL(10,2);
BEGIN
    -- Proceed only if BranchCredits increased
    IF NEW.BranchCredits > OLD.BranchCredits THEN
        -- Calculate total EquivalentTonnes for this company and year
        SELECT SUM(EquivalentTonnes)
        INTO total_equivalent_emission
        FROM CompanyEmission
        WHERE RegNo = NEW.RegNo AND EmissionYear = NEW."Year";

        -- Avoid division by zero or nulls
        IF total_equivalent_emission IS NULL OR total_equivalent_emission = 0 THEN
            RETURN NEW;
        END IF;

        -- Calculate the emission increase based on credit change
        emission_increase := NEW.BranchCredits - OLD.BranchCredits;

        -- Distribute the increase proportionally among gases
        FOR gas_record IN
            SELECT GasName, CompanyType, EquivalentTonnes
            FROM CompanyEmission
            WHERE RegNo = NEW.RegNo AND EmissionYear = NEW."Year"
        LOOP
            UPDATE CompanyEmission
            SET EquivalentTonnes = EquivalentTonnes + (
                (gas_record.EquivalentTonnes / total_equivalent_emission) * emission_increase
            )
            WHERE RegNo = NEW.RegNo
              AND EmissionYear = NEW."Year"
              AND GasName = gas_record.GasName
              AND CompanyType = gas_record.CompanyType;
        END LOOP;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_equivalent_emission
AFTER UPDATE ON Branch
FOR EACH ROW
WHEN (OLD.BranchCredits IS DISTINCT FROM NEW.BranchCredits)
EXECUTE PROCEDURE update_equivalent_emission_on_credit_increase();

--5 Update branchCredits when EquivalentTonnes are increased 
CREATE OR REPLACE FUNCTION adjust_branch_credits_by_size()
RETURNS TRIGGER AS $$
DECLARE
    emission_year INT;
    company_regno NUMERIC(10,2);
    emission_change DECIMAL(12,2);
    total_branch_size DECIMAL(10,2);
    r RECORD;
BEGIN
    -- Determine year and company
    IF TG_OP = 'INSERT' THEN
        emission_year := NEW.EmissionYear;
        company_regno := NEW.RegNo;
        emission_change := NEW.EquivalentTonnes;
    ELSIF TG_OP = 'DELETE' THEN
        emission_year := OLD.EmissionYear;
        company_regno := OLD.RegNo;
        emission_change := -OLD.EquivalentTonnes;
    ELSIF TG_OP = 'UPDATE' THEN
        emission_year := NEW.EmissionYear;
        company_regno := NEW.RegNo;
        emission_change := NEW.EquivalentTonnes - OLD.EquivalentTonnes;
    END IF;

    -- If no change, do nothing
    IF emission_change = 0 THEN
        RETURN NULL;
    END IF;

    -- Total size for all branches of the company that year
    SELECT COALESCE(SUM(Size), 0)
    INTO total_branch_size
    FROM Branch
    WHERE RegNo = company_regno AND "Year" = emission_year;

    IF total_branch_size = 0 THEN
        RETURN NULL; -- Can't distribute if total size is 0
    END IF;

    -- Distribute emission_change based on branch size
    FOR r IN
        SELECT "State", City, Size, BranchCredits
        FROM Branch
        WHERE RegNo = company_regno AND "Year" = emission_year
    LOOP
        UPDATE Branch
        SET BranchCredits = ROUND(BranchCredits + (emission_change * (r.Size / total_branch_size)), 2)
        WHERE RegNo = company_regno AND "State" = r."State" AND City = r.City AND "Year" = emission_year;
    END LOOP;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger for INSERT
CREATE TRIGGER trg_emission_insert
AFTER INSERT ON CompanyEmission
FOR EACH ROW
EXECUTE PROCEDURE adjust_branch_credits_by_size();

-- Trigger for DELETE
CREATE TRIGGER trg_emission_delete
AFTER DELETE ON CompanyEmission
FOR EACH ROW
EXECUTE PROCEDURE adjust_branch_credits_by_size();

-- Trigger for UPDATE
CREATE TRIGGER trg_emission_update
AFTER UPDATE ON CompanyEmission
FOR EACH ROW
EXECUTE PROCEDURE adjust_branch_credits_by_size();

-- 6 Check Available Credits before Transaction
CREATE OR REPLACE FUNCTION check_available_credits_before_transaction()
RETURNS TRIGGER AS $$
DECLARE
    available_credits DECIMAL(10,2);
BEGIN
    -- Calculate available credits from the Credit table for the company
    SELECT (CAllocated + CBuy + CNgo - CProduced- CSell)
    INTO available_credits
    FROM Credit
    WHERE RegNo = NEW.SellerRegNo;

    -- Check if enough credits are available
    IF NEW.CreditsTraded > available_credits THEN
        RAISE EXCEPTION 'Not enough available credits for trade. Requested: %, Available: %', 
            NEW.CreditsTraded, available_credits;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_check_credits_on_transaction
BEFORE INSERT ON "Transaction"
FOR EACH ROW
EXECUTE PROCEDURE check_available_credits_before_transaction();


--7 CNgo as sum of all ngos credit reduced 
CREATE OR REPLACE FUNCTION update_credit_cngo()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE Credit
    SET CNgo = (
        SELECT COALESCE(SUM(n.CreditReduced), 0)
        FROM NGOCollabrations nc
        JOIN NGOs n ON n.NGORegNo = nc.NGORegNo AND n.NGOProjectID = nc.NGOProjectID
        WHERE nc.RegNo = NEW.RegNo AND nc.CreditAllocatedYear = NEW.CreditAllocatedYear
    )
    WHERE Credit.RegNo = NEW.RegNo AND Credit.CreditAllocatedYear = NEW.CreditAllocatedYear;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_after_insert_ncollab
AFTER INSERT OR DELETE OR UPDATE  ON NGOCollabrations
FOR EACH ROW
EXECUTE PROCEDURE update_credit_cngo();


