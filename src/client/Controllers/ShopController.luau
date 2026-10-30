--!strict
-- ShopController (STUB): needs Studio UI/assets.
-- TODO(Studio/Agent D or B): Store UI for passes/products. Use Net.Client.Invoke("GetStoreInfo") for names/prices/owned; Net.Client.Fire("PromptPass"|"PromptProduct", key); gifting via Invoke("PrepareGift", userId, passKey). Never link off-platform.

local ShopController = { Name = "ShopController", Priority = 60 }

function ShopController.Init() end
function ShopController.Start() end

return ShopController
