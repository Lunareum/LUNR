// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./LPSwapSupport.sol";

abstract contract BuyBack is LPSwapSupport {
    using SafeMath for uint256;

    event BuybackTriggered(address indexed tokenReceiver, uint256 buybackAmount);

    struct WhaleSellDefinition {
        uint256 whaleSellPercentage;
        uint256 whaleSellPercentageDivisor;
        uint256 whaleSellBuybackTaxPercentage;
        uint256 whaleSellBuybackTaxPercentageDivisor;
    }

    uint256 private buybackWalletPercent;
    uint256 private buybackWalletPercentDivisor;

    uint256 minBuybackTrigger;

    WhaleSellDefinition public whaleCriteria;

    address public buybackReceiver;
    bool public autoBuybackEnabled;

    constructor() internal LPSwapSupport() {
        buybackReceiver = deadAddress;
        whaleCriteria.whaleSellPercentage = 1;
        whaleCriteria.whaleSellPercentageDivisor = 1000;
        whaleCriteria.whaleSellBuybackTaxPercentage = 2;
        whaleCriteria.whaleSellBuybackTaxPercentageDivisor = 100;
        buybackWalletPercent = 50;
        buybackWalletPercentDivisor = 100;
        minBuybackTrigger = 2 ether;
    }

    function updateBuybackRange(uint256 minAmount, uint256 maxAmount) external onlyOwner {
        require(minAmount <= maxAmount, "Minimum must be less than maximum");
        minSpendAmount = minAmount;
        maxSpendAmount = maxAmount;
    }

    function updateWhaleBuybackSellTax(uint256 additionalBuybackFee, uint256 additionalBuybackFeeDivisor) external onlyOwner {
        whaleCriteria.whaleSellBuybackTaxPercentage = additionalBuybackFee;
        whaleCriteria.whaleSellBuybackTaxPercentageDivisor = additionalBuybackFeeDivisor;
    }

    function updateBuybackTrigger(uint256 buybackTrigger) external onlyOwner {
        minBuybackTrigger = buybackTrigger;
    }

    function updateWhaleSellCriteria(uint256 sellPercentage, uint256 percentageDivisor) external onlyOwner {
        whaleCriteria.whaleSellPercentage = sellPercentage;
        whaleCriteria.whaleSellPercentageDivisor = percentageDivisor;
    }

    function enableAutoBuyback(bool enable) external onlyOwner {
        autoBuybackEnabled = enable;
    }

    function updateBuybackBuyPercentage(uint256 walletPercentageToSell, uint256 divisor) external onlyOwner {
        buybackWalletPercent = walletPercentageToSell;
        buybackWalletPercentDivisor = divisor;
    }

    function checkIfWhaleSell(uint256 amount) internal view returns(bool) {
        return _balanceOf(pancakePair).mul(whaleCriteria.whaleSellPercentage).div(whaleCriteria.whaleSellPercentageDivisor) < amount;
    }

    function shouldAutoBuyback() internal view returns(bool) {
        return autoBuybackEnabled && address(this).balance >= minBuybackTrigger;
    }

    function updateBuybackReceiver(address buyback) external onlyOwner {
        buybackReceiver = buyback;
    }

    function calculateBuybackTax(uint256 amount) internal view returns(uint256){
        return amount.mul(whaleCriteria.whaleSellBuybackTaxPercentage).div(whaleCriteria.whaleSellBuybackTaxPercentageDivisor);
    }

    function manualBuyback(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Contract balance too low for buyback");
        swapCurrencyForTokensUnchecked(address(this), amount, buybackReceiver);
    }

    function autoBuyback() internal {
        if(!inSwap){
            _autoBuyback();
        }
    }

    function _autoBuyback() private lockTheSwap {
        IPancakePair(pancakePair).sync();
        uint256 amount = address(this).balance.mul(buybackWalletPercent).div(buybackWalletPercentDivisor);
        swapCurrencyForTokensAdv(address(this), amount, buybackReceiver);
        emit BuybackTriggered(buybackReceiver, amount);
    }

}
