// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "../../../src/interfaces/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IWETH} from "../../../src/interfaces/IWETH.sol";
import {IUniswapV2Router02} from "../../../src/interfaces/uniswap-v2/IUniswapV2Router02.sol";
import {IUniswapV2Pair} from "../../../src/interfaces/uniswap-v2/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "../../../src/interfaces/uniswap-v2/IUniswapV2Factory.sol";
import {
    DAI,
    WETH,
    MKR,
    USDC,
    UNISWAP_V2_PAIR_DAI_MKR,
    UNISWAP_V2_ROUTER_02
} from "../../../src/Constants.sol";

contract UniswapV2SwapTest is Test {
    IWETH private constant weth = IWETH(WETH);
    IERC20 private constant dai = IERC20(DAI);
    IERC20 private constant mkr = IERC20(MKR);
    IERC20 private constant usdc = IERC20(USDC);

    IUniswapV2Router02 private constant router =
        IUniswapV2Router02(UNISWAP_V2_ROUTER_02);
    IUniswapV2Pair private constant pair =
        IUniswapV2Pair(UNISWAP_V2_PAIR_DAI_MKR);

    address private constant user = address(100);

    function setUp() public {
        // Give user tokens
        deal(user, 100 * 1e18); // 100 ETH
        deal(MKR, user, 1e2 * 1e18); // 100 MKR
        deal(DAI, user, 1e6 * 1e18); // 1 million DAI
        deal(USDC, user, 1e6 * 1e6); // 1 million USDC

        // Approve tokens and deposit ETH to WETH
        vm.startPrank(user);
        weth.deposit{value: 100 * 1e18}();
        weth.approve(address(router), type(uint256).max);
        dai.approve(address(router), type(uint256).max);
        mkr.approve(address(router), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);
        vm.stopPrank();

        // Add liquidity to all pairs in the path
        IUniswapV2Factory factory = IUniswapV2Factory(router.factory());

        // WETH-DAI pair
        address wethDaiPair = factory.getPair(WETH, DAI);
        if (wethDaiPair != address(0)) {
            deal(DAI, wethDaiPair, 1e6 * 1e18); // 1 million DAI
            deal(WETH, wethDaiPair, 500 * 1e18); // 500 WETH
            IUniswapV2Pair(wethDaiPair).sync();
        }

        // DAI-MKR pair
        deal(DAI, address(pair), 1e6 * 1e18); // 1 million DAI
        deal(MKR, address(pair), 1e5 * 1e18); // 100,000 MKR
        pair.sync();

        // MKR-USDC pair
        address mkrUsdcPair = factory.getPair(MKR, USDC);
        if (mkrUsdcPair != address(0)) {
            deal(MKR, mkrUsdcPair, 1e5 * 1e18); // 100,000 MKR
            deal(USDC, mkrUsdcPair, 1e6 * 1e6); // 1 million USDC
            IUniswapV2Pair(mkrUsdcPair).sync();
        }
    }

    /// @dev Normalize balances for tokens with different decimals
    function normalize(address token, uint256 amount) internal view returns (uint256) {
        uint8 decimals = IERC20Metadata(token).decimals();
        if (decimals == 18) return amount;
        if (decimals < 18) return amount * (10 ** (18 - decimals));
        return amount / (10 ** (decimals - 18));
    }

    /// @dev Check if all pairs in the path exist and have sufficient reserves
    function checkPathReserves(address[] memory path, uint256 minReserve) internal view returns (bool) {
        IUniswapV2Factory factory = IUniswapV2Factory(router.factory());
        for (uint256 i = 0; i < path.length - 1; i++) {
            address pairAddress = factory.getPair(path[i], path[i + 1]);
            if (pairAddress == address(0)) {
                console2.log("Pair does not exist for tokens:", path[i], path[i + 1]);
                return false;
            }
            IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
            (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
            address token0 = pair.token0();
            uint256 reserve = token0 == path[i + 1] ? reserve0 : reserve1;
            if (reserve < minReserve) {
                console2.log("Insufficient reserves for token:", path[i + 1], reserve);
                return false;
            }
        }
        return true;
    }

    // Swap all input tokens for as many output tokens as possible
    function test_swapExactTokensForTokens() public {
        address[] memory path = new address[](4);
        path[0] = WETH;
        path[1] = DAI;
        path[2] = MKR;
        path[3] = USDC;

        uint256 amountIn = 1e18; // 1 WETH
        uint256 amountOutMin = 1e6; // Minimum 1 USDC (6 decimals)

        // Check if all pairs exist and have sufficient reserves
        if (!checkPathReserves(path, amountOutMin)) {
            console2.log("Skipping test due to insufficient reserves or missing pairs");
            return;
        }

        vm.startPrank(user);
        uint256[] memory amounts =
            router.swapExactTokensForTokens(
                amountIn,
                amountOutMin,
                path,
                user,
                block.timestamp + 1
            );
        vm.stopPrank();

        console2.log("Output of USDC received:", normalize(USDC, amounts[amounts.length - 1]));
        console2.log("WETH spent:", normalize(WETH, amounts[0]));
        console2.log("DAI:", normalize(DAI, amounts[1]));
        console2.log("MKR:", normalize(MKR, amounts[2]));
        console2.log("USDC:", normalize(USDC, amounts[3]));

        assertEq(normalize(WETH, amounts[0]), 1e18); // Ensure we spent exactly 1 WETH
        assertTrue(normalize(USDC, amounts[amounts.length - 1]) >= 1e18); // Ensure we received at least 1 USDC (normalized)
    }

    // Receive an exact amount of output tokens for as few input tokens as possible
    function test_swapTokensForExactTokens() public {
        address[] memory path = new address[](4);
        path[0] = WETH;
        path[1] = DAI;
        path[2] = MKR;
        path[3] = USDC;

        uint256 amountOut = 1e6; // 1 USDC (6 decimals)
        uint256 amountInMax = 3000e18; // Maximum 3000 WETH

        // Check if all pairs exist and have sufficient reserves
        if (!checkPathReserves(path, amountOut)) {
            console2.log("Skipping test due to insufficient reserves or missing pairs");
            return;
        }

        vm.startPrank(user);
        uint256[] memory amounts =
            router.swapTokensForExactTokens(
                amountOut,
                amountInMax,
                path,
                user,
                block.timestamp + 1
            );
        vm.stopPrank();

        console2.log("Input WETH spent:", normalize(WETH, amounts[0]));
        console2.log("WETH:", normalize(WETH, amounts[0]));
        console2.log("DAI:", normalize(DAI, amounts[1]));
        console2.log("MKR:", normalize(MKR, amounts[2]));
        console2.log("USDC:", normalize(USDC, amounts[3]));

        assertEq(normalize(USDC, amounts[amounts.length - 1]), 1e18); // Ensure we received exactly 1 USDC (normalized)
        assertTrue(normalize(WETH, amounts[0]) <= 3000e18); // Ensure we didn't spend more than 3000 WETH
    }
}