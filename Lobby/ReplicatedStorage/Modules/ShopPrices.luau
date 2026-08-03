local ShopPrices = {}

ShopPrices.Prices = {
	Item1 = 30,
	Item2 = 40,
	Item3 = 50,
	Item4 = 60,
}

function ShopPrices.GetPrice(itemName)
	return ShopPrices.Prices[itemName]
end

return ShopPrices