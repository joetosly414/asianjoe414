const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SimpleApeCoinStaking", function () {
  let stakingContract;
  let stakingToken;
  let rewardToken;
  let owner;
  let user1;
  let user2;

  const INITIAL_SUPPLY = ethers.parseEther("1000000");
  const INITIAL_REWARD_RATE = ethers.parseEther("1"); // 1 token per second per token staked
  const INITIAL_STAKING_CAP = ethers.parseEther("10000");

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    // Deploy tokens
    const SimpleERC20 = await ethers.getContractFactory("SimpleERC20");
    stakingToken = await SimpleERC20.deploy("ApeCoin", "APE", 18, INITIAL_SUPPLY);
    rewardToken = await SimpleERC20.deploy("RewardToken", "RWD", 18, INITIAL_SUPPLY);

    // Deploy staking contract
    const SimpleApeCoinStaking = await ethers.getContractFactory("SimpleApeCoinStaking");
    stakingContract = await SimpleApeCoinStaking.deploy(
      await stakingToken.getAddress(),
      await rewardToken.getAddress(),
      INITIAL_REWARD_RATE,
      INITIAL_STAKING_CAP
    );

    // Setup token balances
    await stakingToken.mint(user1.address, ethers.parseEther("100000"));
    await stakingToken.mint(user2.address, ethers.parseEther("100000"));

    // Transfer reward tokens to staking contract
    await rewardToken.transfer(await stakingContract.getAddress(), ethers.parseEther("500000"));
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await stakingContract.owner()).to.equal(owner.address);
    });

    it("Should set correct initial values", async function () {
      expect(await stakingContract.rewardRate()).to.equal(INITIAL_REWARD_RATE);
      expect(await stakingContract.stakingCap()).to.equal(INITIAL_STAKING_CAP);
      expect(await stakingContract.totalStaked()).to.equal(0);
    });
  });

  describe("Staking", function () {
    it("Should allow users to stake tokens", async function () {
      const stakeAmount = ethers.parseEther("1000");
      
      await stakingToken.connect(user1).approve(await stakingContract.getAddress(), stakeAmount);
      await stakingContract.connect(user1).stake(stakeAmount);

      expect(await stakingContract.stakedBalance(user1.address)).to.equal(stakeAmount);
      expect(await stakingContract.totalStaked()).to.equal(stakeAmount);
    });

    it("Should reject staking 0 amount", async function () {
      await expect(stakingContract.connect(user1).stake(0))
        .to.be.revertedWith("Cannot stake 0");
    });

    it("Should enforce staking cap", async function () {
      const excessAmount = INITIAL_STAKING_CAP + ethers.parseEther("1");
      
      await stakingToken.connect(user1).approve(await stakingContract.getAddress(), excessAmount);
      await expect(stakingContract.connect(user1).stake(excessAmount))
        .to.be.revertedWith("Staking cap exceeded");
    });
  });

  describe("Withdrawing", function () {
    beforeEach(async function () {
      const stakeAmount = ethers.parseEther("1000");
      await stakingToken.connect(user1).approve(await stakingContract.getAddress(), stakeAmount);
      await stakingContract.connect(user1).stake(stakeAmount);
    });

    it("Should allow users to withdraw staked tokens", async function () {
      const withdrawAmount = ethers.parseEther("500");
      const balanceBefore = await stakingToken.balanceOf(user1.address);
      
      await stakingContract.connect(user1).withdraw(withdrawAmount);
      
      const balanceAfter = await stakingToken.balanceOf(user1.address);
      expect(balanceAfter - balanceBefore).to.equal(withdrawAmount);
      expect(await stakingContract.stakedBalance(user1.address)).to.equal(ethers.parseEther("500"));
    });

    it("Should reject withdrawing 0 amount", async function () {
      await expect(stakingContract.connect(user1).withdraw(0))
        .to.be.revertedWith("Cannot withdraw 0");
    });

    it("Should reject withdrawing more than staked", async function () {
      const excessAmount = ethers.parseEther("2000");
      await expect(stakingContract.connect(user1).withdraw(excessAmount))
        .to.be.revertedWith("Insufficient staked balance");
    });
  });

  describe("Rewards", function () {
    beforeEach(async function () {
      const stakeAmount = ethers.parseEther("1000");
      await stakingToken.connect(user1).approve(await stakingContract.getAddress(), stakeAmount);
      await stakingContract.connect(user1).stake(stakeAmount);
    });

    it("Should accumulate rewards over time", async function () {
      // Fast forward time
      await ethers.provider.send("evm_increaseTime", [3600]); // 1 hour
      await ethers.provider.send("evm_mine");

      const earned = await stakingContract.earned(user1.address);
      expect(earned).to.be.gt(0);
    });

    it("Should allow claiming rewards", async function () {
      // Fast forward time
      await ethers.provider.send("evm_increaseTime", [3600]); // 1 hour
      await ethers.provider.send("evm_mine");

      const earnedBefore = await stakingContract.earned(user1.address);
      const balanceBefore = await rewardToken.balanceOf(user1.address);
      
      await stakingContract.connect(user1).claimReward();
      
      const balanceAfter = await rewardToken.balanceOf(user1.address);
      expect(balanceAfter - balanceBefore).to.equal(earnedBefore);
    });
  });

  describe("Admin Functions", function () {
    it("Should allow owner to set reward rate", async function () {
      const newRewardRate = ethers.parseEther("2");
      await stakingContract.setRewardRate(newRewardRate);
      expect(await stakingContract.rewardRate()).to.equal(newRewardRate);
    });

    it("Should allow owner to set staking cap", async function () {
      const newStakingCap = ethers.parseEther("20000");
      await stakingContract.setStakingCap(newStakingCap);
      expect(await stakingContract.stakingCap()).to.equal(newStakingCap);
    });

    it("Should allow owner to pause/unpause", async function () {
      await stakingContract.pause();
      expect(await stakingContract.paused()).to.be.true;

      await stakingContract.unpause();
      expect(await stakingContract.paused()).to.be.false;
    });

    it("Should reject non-owner admin calls", async function () {
      await expect(stakingContract.connect(user1).setRewardRate(ethers.parseEther("2")))
        .to.be.revertedWith("Not the owner");
    });
  });

  describe("Emergency Withdraw", function () {
    beforeEach(async function () {
      const stakeAmount = ethers.parseEther("1000");
      await stakingToken.connect(user1).approve(await stakingContract.getAddress(), stakeAmount);
      await stakingContract.connect(user1).stake(stakeAmount);
    });

    it("Should allow owner to emergency withdraw for users", async function () {
      const balanceBefore = await stakingToken.balanceOf(user1.address);
      
      await stakingContract.emergencyWithdraw(user1.address);
      
      const balanceAfter = await stakingToken.balanceOf(user1.address);
      expect(balanceAfter - balanceBefore).to.equal(ethers.parseEther("1000"));
      expect(await stakingContract.stakedBalance(user1.address)).to.equal(0);
    });
  });
});