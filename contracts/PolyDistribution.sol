pragma solidity ^0.4.18;

import '../interfaces/IERC20.sol';
import './PolyToken.sol';
import './SafeMath.sol';
import './Ownable.sol';

/**
 * @title POLY token initial distribution
 *
 * @dev Distribute investor, airdrop, reserve, and founder tokens
 */
contract PolyDistribution is Ownable {
  using SafeMath for uint256;

  PolyToken public POLY;

  uint256 private constant decimals = 10**uint256(18);
  enum AllocationType { INVESTOR, FOUNDER, AIRDROP, BDMARKET, ADVISOR, RESERVE }
  uint256 public AVAILABLE_INVESTOR_SUPPLY = 200000000;// 100% Release Jan 24th 2018
  uint256 public AVAILABLE_FOUNDER_SUPPLY  = 150000000; // 25% Release Jan 24th, 2019 + 25% release yearly after
  uint256 public AVAILABLE_AIRDROP_SUPPLY  = 100000000; // 10% Released Jan 24th, 2019 + 10% monthly after\
  uint256 public AVAILABLE_BDMARKET_SUPPLY = 50000000;  // 100% Release Jan 24th 2018
  uint256 public AVAILABLE_ADVISOR_SUPPLY  = 25000000;  // 100% Released on Sept 24th, 2018
  uint256 public AVAILABLE_RESERVE_SUPPLY  = 475000000; // 10M Released on July 24th, 2018 - 10M montly after
  uint256 grandTotalAllocated = 0;
  uint256 grandTotalClaimed = 0;
  uint256 startTime;

  // Allocation with vesting information
  struct Allocation {
    uint8 AllocationSupply; // Type of allocation
    uint256 cliffDuration;  // Tokens are locked until
    uint256 endVesting;     // This is when the tokens are fully unvested
    uint256 totalAllocated; // Total tokens allocated
    uint256 amountClaimed;  // Total tokens claimed
  }
  mapping (address => Allocation) public allocations;

  event LogNewAllocation(address _recipient, string _fromSupply, uint256 _totalAllocated, uint256 _grandTotalAllocated);
  event LogPolyClaimed(address _recipient, uint8 _fromSupply, uint256 _amountClaimed, uint256 _totalAllocated, uint256 _grandTotalClaimed);

  /**
    * @dev Constructor function - Set the poly token address
    */
  function PolyDistribution (address _polyTokenAddress) public {
    POLY = PolyToken(_polyTokenAddress);
  }

  /**
    * @dev Allow the owner of the contract to assign a new allocation
    * @param _recipient The recipient of the allocation
    * @param _totalAllocated The total amount of POLY available to the receipient (after vesting)
    * @param _supply The POLY supply the allocation will be taken from
    */
  function setAllocation (address _recipient, uint256 _totalAllocated, uint8 _supply) onlyOwner public {
    require(allocations[_recipient].totalAllocated == 0);
    require(_totalAllocated > 0);
    string memory fromSupply;
    if (_supply == 1) {
      fromSupply = 'investor';
      AVAILABLE_INVESTOR_SUPPLY.sub(_totalAllocated);
      allocations[_recipient] = Allocation(AllocationType.INVESTOR, 0, 0, _totalAllocated, 0);
    } else if (_supply == 2) {
      fromSupply = 'founder';
      AVAILABLE_FOUNDER_SUPPLY.sub(_totalAllocated);
      allocations[_recipient] = Allocation(AllocationType.FOUNDER, 1 years, 4 years, _totalAllocated, 0);
    } else if (_supply == 3) {
      fromSupply = 'airdrop';
      AVAILABLE_AIRDROP_SUPPLY.sub(_totalAllocated);
      allocations[_recipient] = Allocation(AllocationType.AIRDROP, 0, 1 years, _totalAllocated, 0);
    } else if (_supply == 4) {
      fromSupply = 'bdmarket';
      AVAILABLE_BDMARKET_SUPPLY.sub(_totalAllocated);
      allocations[_recipient] = Allocation(AllocationType.BDMARKET, 0, 0, _totalAllocated, 0);
    } else if (_supply == 5) {
      fromSupply = 'advisor';
      AVAILABLE_ADVISOR_SUPPLY.sub(_totalAllocated);
      allocations[_recipient] = Allocation(AllocationType.ADVISOR, 215 days, 0, _totalAllocated, 0);
    } else if (_supply == 6) {
      fromSupply = 'reserve';
      AVAILABLE_RESERVE_SUPPLY.sub(_totalAllocated);
      allocations[_recipient] = Allocation(AllocationType.RESERVE, 100 days, 4 years, _totalAllocated, 0);
    }
    grandTotalAllocated.add(_totalAllocated);
    LogNewAllocation(_recipient, fromSupply, _totalAllocated, grandTotalAllocated);
  }

  /**
    * @dev Allow the recipient to claim their allocation
    */
  function claimTokens () public {
    require(allocations[msg.sender].amountClaimed < allocations[msg.sender].totalAllocated);
    require(block.timestamp >= startTime + allocations[msg.sender].cliffDuration);
    // Determine the available amount that can be claimed
    if (allocations[msg.sender].endVesting > now) {
      uint256 availableAtTime = allocations[msg.sender].totalAllocated.mul(now).div(allocations[msg.sender].endVesting);
      uint256 availablePolyToClaim = availableAtTime.sub(allocations[msg.sender].amountClaimed);
      grandTotalClaimed.add(availablePolyToClaim);
      allocations[msg.sender].amountClaimed = availableAtTime;
      POLY.transfer(msg.sender, availablePolyToClaim);
    } else {
      allocations[msg.sender].amountClaimed = allocations[msg.sender].totalAllocated;
      grandTotalClaimed.add(allocations[msg.sender].totalAllocated);
      POLY.transfer(msg.sender, allocations[msg.sender].totalAllocated);
    }
    LogPolyClaimed(msg.sender, allocations[msg.sender].AllocationSupply, allocations[msg.sender].amountClaimed, allocations[msg.sender].totalAllocated, grandTotalClaimed);
  }

  // Prevent accidental ether payments to the contract
  function () public {
    revert();
  }

  // Allow transfer of accidentally sent ERC20 tokens
  function refundTokens(address _recipient, address _token) public onlyOwner {
    require(_token != address(this));
    IERC20 token = IERC20(_token);
    uint256 balance = token.balanceOf(this);
    token.transfer(_recipient, balance);
  }
}