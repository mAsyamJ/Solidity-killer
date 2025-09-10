// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ExchangeV1 {
    address public token;
    uint256 public tokenReserve;
    bool private locked;
    uint256 public Fee = 1000; // 1 ETH = 1000 tokens
                                // 997 = 1000(1-0.3%) the fee is 0.3%

    modifier notReentrant() {
        require(!locked, "Contract is locked");
        locked = true;
        _;
        locked = false;
    }
    
    // How?
    // Insufficient output (slippage)
    // Empty reserves

    event TokenPurchase(address indexed buyer, uint256 ethSold, uint256 tokensBought, address indexed to);
    event EthPurchase(address indexed buyer, uint256 tokensSold, uint256 ethBought, address indexed to);

    constructor (address _token) {
        require(_token != address(0), "Token address cannot be zero");
        token = IERC20(_token);
        tokenReserve = 0;
        // why liquiity did not said in constructor?       
    }   

    // receive ETH
    // why payable?
    receive() external payable;

    //  // // 3. Swap functions:
    // // 1. ethToTokenSwapExactIn = ETH in → Token out
    // // 2. tokenToEthSwapExactIn = Token in → ETH out
    // only payable in function 1, because eth in and in contact with contract (EVM) that can handle ETH but not ERC-20 Tokens

     // ETH -> Token (exact ETH input): user sends ETH in msg.value, receives computed tokens
    function ethToTokenSwapExactIn(
        uint256 minTokensOut, 
        address _to, 
        bool _locked) public payable nonReentrant {
            require(msg.value > 0, "No ETH sent"); 
            require(_to != address(0), "to non addresss");

            uint256 ethReservePrior = address(this).balance - msg.value;
            require(ethReservePrior > 0, "Empty reserves"); // no liquidity)

            // Compute tokensOut using 0.3% fee
            uint256 dxWithFee = msg.value * 997; // dxEff * 1000
            uint256 numerator = dxWithFee * tokenReserve; // dx_eff * y_prior * 1000
            uint256 denominator = ethReservePrior * 1000 + dxWithFee; // (x_prior * 1000
            uint256 tokensOut= numerator / denominator; // dy = (dx_eff * y_prior) / (x_prior + dx_eff)
            require(tokenOut > 0 && tokenOut >= minTokensOut, "Insufficient output");

            // Transfer tokens to buyer
            require(IERC20(token).transfer(_to, tokensOut), "Transfer failed");

            // Effects: sync token reserve after reseiving tokens
            _syncTokenReserve();

            // emit TokenPurchase(buyer, ethSold, tokensBought, to);
            emit TokenPurchase(msg.sender, msg.value, tokensOut, to);
    }

    // Token -> ETH: user sell tokens; contract pays ETH
    // why non-payable?
    function tokenToEthSwapExactIn(
        uint256 tokenSold, 
        uint256 minEthOut, 
        address _to, 
        bool _locked) public {
            require(tokenSold > 0, "No tokens sent");
            require(_to != address(0), "to non addresss");

            uint256 ethReserve = token.balanceOf(address(this));
            require(ethReserve > 0 && tokenReserve > 0, "Empty reserves"); // no liquidity

            // Compute EthOut using *prior* token reserve (before pulling tokens)
            uint256 dyWithFee = tokenSold * 997; // dyEff * 1000
            uint256 numerator = dyWithFee * ethReserve; // dy_eff * x_prior * 1000
            uint256 denominator = tokenReserve * 1000 + dyWithFee; // (y_prior * 1000 + dy_eff)
            uint256 ethOut = numerator/denominator;
            require(ethOut > 0 && ethOut >= minEthOut, "Insufficient output");

            // Pull tokens in from buyer
            require(IERC20(token).transferFrom(msg.sender, address(this), tokenSold), "Transfer failed");
            
            // Interaction: send ETH out (use call, not transfer)
            (bool ok, ) = to.call{value: ethOut}("");
            require(ok, "ETH send failed");

            // Effects: sync token reserve after receiving tokens
            _syncTokenReserve();

            // event EthPurchase(address indexed buyer, uint256 tokensSold, uint256 ethBought, address indexed to);
            emit EthPurchase(msg.sender, tokenSold, ethOut, _to);
    }

    function getEthToTokenInputPrice(uint256 ethSold) public view returns (uint256) {
        uint256 numerator = ethSold * tokenReserve * 1000;
        uint256 denominator = (ethBalance() * 1000) + (ethSold * 1000);
        return numerator / denominator;
    }

    function getTokenToEthInputPrice(uint256 tokenSold) public view returns (uint256) {

    }

    function getEthToTokenOutputPrice(uint256 tokensBought) public view returns (uint256) {
        
    }

    function getTokenToEthOutputPrice(uint256 EthBought) public view returns (uint256) {

    }

    function _syncTokenReserve() internal {
        tokenReserve = token.balanceOf(address(this));
    }

    // 4. Reserve sync (internal) helper stub you’ll call after swaps.


}
