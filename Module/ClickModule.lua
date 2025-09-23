local ClickModule = {}

function ClickModule.OnClick(player, folder)
	print(folder)
	local clicks = folder.Data.MainData.Clicks
	local clickPlus = folder.Data.PlusData.ClickPlus
	clicks = clicks + clickPlus
	folder:Update('MainData', 'Clicks', clicks)
end

return ClickModule