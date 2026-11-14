--!strict
-- ReceiptLedger: the idempotent core of MarketService.ProcessReceipt (guide §8.2 rule 6).
--
-- Rule, as implemented here and in MarketService:
--   1. Load the buyer's profile. If it is not loaded (player gone / still loading) -> NotProcessedYet.
--   2. If receiptInfo.PurchaseId is already in profile.receipts -> PurchaseGranted (never grant twice).
--   3. Grant the product to the profile data. If granting fails -> NotProcessedYet (nothing recorded).
--   4. Record the PurchaseId (capped FIFO history) in the SAME data table as the grant.
--   5. Return PurchaseGranted only after the profile has been saved with that PurchaseId
--      (MarketService waits for Profile.OnAfterSave); otherwise NotProcessedYet and Roblox retries,
--      at which point step 2 makes the retry a no-op.
-- This module covers steps 2-4, which are pure and unit-tested.

local ReceiptLedger = {}

export type Ledger = {
	receipts: { [string]: boolean },
	receiptOrder: { string },
	robuxSpent: number,
}

export type Decision = "AlreadyGranted" | "Granted" | "GrantFailed"

function ReceiptLedger.HasReceipt(ledger: Ledger, purchaseId: string): boolean
	return ledger.receipts[purchaseId] == true
end

local function record(ledger: Ledger, purchaseId: string, limit: number)
	ledger.receipts[purchaseId] = true
	table.insert(ledger.receiptOrder, purchaseId)
	while #ledger.receiptOrder > limit do
		local oldest = table.remove(ledger.receiptOrder, 1)
		if oldest then
			ledger.receipts[oldest] = nil
		end
	end
end

-- grant() must mutate the same profile data the ledger lives in and return true on success.
-- If grant errors or returns false, nothing is recorded so Roblox will retry later.
function ReceiptLedger.Apply(
	ledger: Ledger,
	purchaseId: string,
	robuxSpent: number,
	limit: number,
	grant: () -> boolean
): Decision
	if ReceiptLedger.HasReceipt(ledger, purchaseId) then
		return "AlreadyGranted"
	end
	local ok, granted = pcall(grant)
	if not ok or granted ~= true then
		if not ok then
			warn("[ReceiptLedger] grant error:", granted)
		end
		return "GrantFailed"
	end
	record(ledger, purchaseId, limit)
	ledger.robuxSpent += robuxSpent
	return "Granted"
end

return ReceiptLedger
