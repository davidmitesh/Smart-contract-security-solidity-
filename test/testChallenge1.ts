import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { token } from "../typechain-types/@openzeppelin/contracts";

describe("Dex Exploit", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshopt in every test.
  async function deployDexContract() {
    
    const [token1_owner, token2_owner,dex_initializer,user2,user3,attacker1,attacker2,dexowner] = await ethers.getSigners();


    const Token = await ethers.getContractFactory("Token");
    const token1 = await Token.connect(token1_owner).deploy("Token1", "TKN1");
    const token2 = await Token.connect(token2_owner).deploy("Token2", "TKN2");

    //sending token1 and token2 funds to test users who will act as the dex participants

    await token1.connect(token1_owner).transfer(dex_initializer.address,100);
    await token2.connect(token2_owner).transfer(dex_initializer.address,100);
    await token1.connect(token1_owner).transfer(user2.address,100);
    await token2.connect(token2_owner).transfer(user2.address,100);
    await token1.connect(token1_owner).transfer(user3.address,100);
    await token2.connect(token2_owner).transfer(user3.address,100);

    //deploying the Dex contract
    const Dex = await ethers.getContractFactory("Dex");
    const dex = await Dex.connect(dexowner).deploy(token1.address,token2.address,dexowner.address)
    
    //initilializing the dex contract
    await token1.connect(dex_initializer).approve(dex.address,50)
    await token2.connect(dex_initializer).approve(dex.address,50)
    await dex.connect(dex_initializer).init(50,50)

    //users adding liquidity to the pool
    await token1.connect(user2).approve(dex.address,50)
    await token2.connect(user2).approve(dex.address,50)
    await dex.connect(user2).addLiquidity(50)

    await token1.connect(user3).approve(dex.address,50)
    await token2.connect(user3).approve(dex.address,50)
    await dex.connect(user3).addLiquidity(50)

    return { token1,token2,token1_owner,token2_owner,dex_initializer,dexowner,attacker1,attacker2,user2,user3,dex };
  }

  describe("Checking the Dex Deployment", function () {
    it("Should show the right shares of the user", async function () {
      const { dex_initializer,user2,user3,dex} = await loadFixture(deployDexContract);

      expect(await dex.shares(dex_initializer.address)).to.equal(50);
      expect(await dex.shares(user2.address)).to.equal(50);
      expect(await dex.shares(user3.address)).to.equal(50);
    });

    it("Should show the total shares of dex", async function () {
      const { dex} = await loadFixture(deployDexContract);

      expect(await dex.totalShares()).to.equal(150);
    });

    it("Should show correct relation between shares and the tokens", async function () {
      const { token1,token2,dex} = await loadFixture(deployDexContract);
      expect(await token1.balanceOf(dex.address)).to.equal(
        150
      );
      expect(await token2.balanceOf(dex.address)).to.equal(
        150
      );
    });
  });

  describe("Exploit Testing", function () {
    describe("Deploying the Attack1 contract", function () {

      it("Should steal the funds from the dex contract", async function () {
        
        const { dex,token1,token2,attacker1,token1_owner,token2_owner} = await loadFixture(deployDexContract);

        //deploying the attack1 contract
        const AttackContract1 = await ethers.getContractFactory('Attack1')
        const attackContract1 = await AttackContract1.connect(attacker1).deploy()

        //transferring some tokens to the attack contract
        await token1.connect(token1_owner).transfer(attackContract1.address,50);
        await token2.connect(token2_owner).transfer(attackContract1.address,50);


        //calling the attack function
        await attackContract1.attack(dex.address,token1.address,token2.address)

        //checking the balances of the dex contract for tokens
        const token1Balance = await token1.balanceOf(dex.address)
        const token2Balance = await token2.balanceOf(dex.address)

        //checking the attacker contract balance before attack
        const token1Bal = await token1.balanceOf(attackContract1.address)
        const token2bal = await token2.balanceOf(attackContract1.address)

        //checking the token balances of the attack contract
         expect(await token1.balanceOf(attackContract1.address)).to.equal(token1Balance.add(token1Bal))
         expect(await token2.balanceOf(attackContract1.address) ).to.equal(token2Balance.add(token2bal))

      });

    
    });

    describe("Deploying the Attack2 contract", function () {

      it("Should steal the funds from the dex contract", async function () {
        
        const { dex,token1,token2,attacker2,token1_owner,token2_owner} = await loadFixture(deployDexContract);

        //deploying the attack2 contract
        const AttackContract2 = await ethers.getContractFactory('Attack2')
        const attackContract2 = await AttackContract2.connect(attacker2).deploy(token1.address,token2.address,dex.address)

        //transferring some tokens to the attack contract
        await token1.connect(token1_owner).transfer(attackContract2.address,50);
        await token2.connect(token2_owner).transfer(attackContract2.address,50);


        //calling the attack function
        await attackContract2.startExploit()

        //checking the balances of the dex contract for tokens
        const token1Balance = await token1.balanceOf(dex.address)
        const token2Balance = await token2.balanceOf(dex.address)

        //checking the attacker contract balance before attack
        const token1Bal = await token1.balanceOf(attackContract2.address)
        const token2bal = await token2.balanceOf(attackContract2.address)

        //checking the token balances of the attack contract
         expect(await token1.balanceOf(attackContract2.address)).to.equal(token1Balance.add(token1Bal))
         expect(await token2.balanceOf(attackContract2.address) ).to.equal(token2Balance.add(token2bal))

      });

    
    });
  });
});
