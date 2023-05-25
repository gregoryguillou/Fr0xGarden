// SPDX-License-Identifier: UNLICENSED
/* solhint-disable var-name-mixedcase */
/* solhint-disable func-name-mixedcase */
pragma solidity ^0.8.17;

import {IPyth} from "@pythnetwork/IPyth.sol";
import {PythStructs} from "@pythnetwork/PythStructs.sol";

contract PythPriceData {
    IPyth pyth;

    bytes32 ETH_PRICE_ID;

    //TODO: Implement test
    constructor(address _pythContract, bytes32 _ethPriceId) {
        pyth = IPyth(_pythContract);
        ETH_PRICE_ID = _ethPriceId;
    }

    function getETHUSDPrice(bytes[] calldata _priceUpdateData) public payable returns (PythStructs.Price memory) {
        uint256 fee = pyth.getUpdateFee(_priceUpdateData);
        pyth.updatePriceFeeds{value: fee}(_priceUpdateData);

        return pyth.getPrice(ETH_PRICE_ID);
    }
}
