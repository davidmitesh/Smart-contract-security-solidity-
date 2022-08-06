// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

contract Dex {
    //no reason to keep all the variables public, as it will generate getter function and increases the code size
    address public owner; //also the wallet controlled by a single owner
    bool public paused;

    //not using safeERC wrapper
    //It’s a helper to make safe the interaction with someone else’s ERC20 token, in your contracts.

    // What the helper does for you is:

    // check the boolean return values of ERC20 operations and revert the transaction if they fail,
    // at the same time allowing you to support some non-standard ERC20 tokens that don’t have boolean return values

    //so we must use using SafeERC20 for IERC20;

    IERC20 public token1;
    IERC20 public token2;
    uint256 private k;

    uint256 public totalShares;
    mapping(address => uint256) public shares;

    constructor(
        IERC20 _token1,
        IERC20 _token2,
        address _owner
    ) {
        //Not checking for zero addresses
        //Not checking if token 1 and token 2 are same and are valid ones.
        token1 = _token1;
        token2 = _token2;
        owner = _owner;
        //Not emitting event with parameters on deployment
    }

    //missing netspec documentation of the function
    function init(uint256 amount1, uint256 amount2) external {
        //if the token1 and token2 balance are emptied then this function can be called mtwice as well, which shouldnot be the case for initialize
        require(
            token1.balanceOf(address(this)) == 0 &&
                token2.balanceOf(address(this)) == 0
        );
        require(token1.transferFrom(msg.sender, address(this), amount1));
        require(token2.transferFrom(msg.sender, address(this), amount2));

        //only token1 is needed to be non zero for non zero shares, we can pass amount2=zer still get shares
        totalShares = shares[msg.sender] = amount1;
        _sync();
    }

    modifier notPaused() {
        require(!paused);
        _;
    }

    function pause() external {
        require(msg.sender == owner);
        paused = true;
    }

    function unpause() external {
        require(msg.sender == owner);
        paused = false;
        _sync();
    }

    function swap(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 amountOut
    ) external notPaused {
        require(
            (tokenIn == token1 && tokenOut == token2) ||
                (tokenIn == token2 && tokenOut == token1)
        );
        //Not using the safeTransfer
        require(tokenIn.transferFrom(msg.sender, address(this), amountIn));
        require(tokenOut.transfer(msg.sender, amountOut));
        //Since we havenot kept track of the previous balance before transfer and after transfer, we cannot tell if the transfer has really happened
        uint256 x = tokenIn.balanceOf(address(this));
        uint256 y = tokenOut.balanceOf(address(this));
        // console.log("value of k is ", k);
        //not checking if balance is able to cover the amount out
        require(1000 * x * y - amountIn * y * 5 >= 1000 * k, "bad swap"); // charge fee, (x - 0.005 * amountIn) * y >= k
        _sync();
        //swap is state transition, so it should emit an event
    }

    function addLiquidity(uint256 sharesToMint) external notPaused {
        // amount / balanceOf == sharesToMint / totalShares
        //missing require (sharesToMint>0,"zero not allowed")
        uint256 amount1 = (token1.balanceOf(address(this)) * sharesToMint) /
            totalShares;
        uint256 amount2 = (token2.balanceOf(address(this)) * sharesToMint) /
            totalShares;
        shares[msg.sender] += sharesToMint;
        totalShares += sharesToMint;
        require(token1.transferFrom(msg.sender, address(this), amount1));
        require(token2.transferFrom(msg.sender, address(this), amount2));
        _sync();
    }

    function removeLiquidity(uint256 sharesToBurn) external {
        uint256 amount1 = (token1.balanceOf(address(this)) * sharesToBurn) /
            totalShares;
        uint256 amount2 = (token2.balanceOf(address(this)) * sharesToBurn) /
            totalShares;
        shares[msg.sender] -= sharesToBurn;
        totalShares -= sharesToBurn;
        require(token1.transfer(msg.sender, amount1));
        require(token2.transfer(msg.sender, amount2));
        _sync();
    }

    function flashLoan(
        IERC3156FlashBorrower receiver,
        IERC20 token,
        uint256 amount,
        bytes calldata data
    ) external notPaused returns (bool) {
        //here is no limit how much the token be borrowed from flashloan, as one can take the whole token
        require(token == token1 || token == token2);
        uint256 fee = (amount * 5) / 1000; // 0.5 %
        require(token.transfer(address(receiver), amount)); //the borrower can essentially empty whole token1 or token2

        //suppose after the token is transferred, then the onFlashLoan is called on the receiver side, and if the attacker calls the flashLoan again with other token and the total amount
        //of that token, then both tokens are emptied from the dex. Now, after that if the attacker calls the init method on dex and passes very small values, then the whole
        //of the dex will be in the name of attacker. Now, at the end of this transaction call, the value is returned to the dex. And if after this, attacker calls the removeLiquidity, then
        //all of the two tokens balances will be transferred to the attacker which is very severe attack.
        require(
            receiver.onFlashLoan(
                msg.sender,
                address(token),
                amount,
                fee,
                data
            ) == keccak256("ERC3156FlashBorrower.onFlashLoan")
        );
        require(
            IERC20(token).transferFrom(
                address(receiver),
                address(this),
                amount + fee
            )
        );
        _sync();
        return true;
    }

    function _sync() internal {
        k = token1.balanceOf(address(this)) * token2.balanceOf(address(this));
    }
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
