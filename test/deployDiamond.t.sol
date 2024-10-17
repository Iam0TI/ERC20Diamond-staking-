// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/ERC20Facet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/Diamond.sol";

import "./helpers/DiamondUtils.sol";

contract DiamondDeployer is DiamondUtils, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    ERC20Facet erc20F;
    address owner = address(0xBEEF);
    address addr1 = address(0xCAFE);
    address addr2 = address(0xDEAD);

    // function testDeployDiamond() public {
    //     //deploy facets
    //     dCutFacet = new DiamondCutFacet();
    //     diamond = new Diamond(address(this), address(dCutFacet), "Program Analysis", "PA", 18);
    //     dLoupe = new DiamondLoupeFacet();
    //     ownerF = new OwnershipFacet();
    //     erc20F = new ERC20Facet();

    //     //upgrade diamond with facets

    //     //build cut struct
    //     FacetCut[] memory cut = new FacetCut[](3);

    //     cut[0] = (
    //         FacetCut({
    //             facetAddress: address(dLoupe),
    //             action: FacetCutAction.Add,
    //             functionSelectors: generateSelectors("DiamondLoupeFacet")
    //         })
    //     );

    //     cut[1] = (
    //         FacetCut({
    //             facetAddress: address(ownerF),
    //             action: FacetCutAction.Add,
    //             functionSelectors: generateSelectors("OwnershipFacet")
    //         })
    //     );
    //     cut[2] = (
    //         FacetCut({
    //             facetAddress: address(erc20F),
    //             action: FacetCutAction.Add,
    //             functionSelectors: generateSelectors("ERC20Facet")
    //         })
    //     );

    //     //upgrade diamond
    //     IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

    //     //call a function
    //     DiamondLoupeFacet(address(diamond)).facetAddresses();
    // }

    function setUp() public {
        // deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet), "Program Analysis", "PA", 18, 4);
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        erc20F = new ERC20Facet();

        // upgrade diamond with facets
        FacetCut[] memory cut = new FacetCut[](3);
        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupe),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(ownerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OwnershipFacet")
            })
        );
        cut[2] = (
            FacetCut({
                facetAddress: address(erc20F),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("ERC20Facet")
            })
        );

        // upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        // Minting to the owner
        vm.prank(owner); // Set the msg.sender to owner
        erc20F.mint(owner, 1000 ether);
    }

    function testTotalSupply() public {
        uint256 totalSupply = erc20F.totalSupply();
        assertEq(totalSupply, 1000 ether, "Total supply should be 1000 tokens");
    }

    function testBalanceOfOwner() public {
        uint256 balance = erc20F.balanceOf(owner);
        assertEq(balance, 1000 ether, "Owner balance should be 1000 tokens");
    }

    function testTransfer() public {
        // Transfer 100 tokens from owner to addr1
        vm.prank(owner); // Set msg.sender to owner
        erc20F.transfer(addr1, 100 ether);

        uint256 ownerBalance = erc20F.balanceOf(owner);
        uint256 addr1Balance = erc20F.balanceOf(addr1);

        assertEq(ownerBalance, 900 ether, "Owner should have 900 tokens left");
        assertEq(addr1Balance, 100 ether, "addr1 should have 100 tokens");
    }

    function testApproveAndTransferFrom() public {
        vm.prank(owner);
        erc20F.approve(addr1, 50 ether);

        vm.prank(addr1); // Set msg.sender to addr1
        erc20F.transferFrom(owner, addr2, 50 ether);

        uint256 ownerBalance = erc20F.balanceOf(owner);
        uint256 addr2Balance = erc20F.balanceOf(addr2);

        assertEq(ownerBalance, 950 ether, "Owner should have 950 tokens left");
        assertEq(addr2Balance, 50 ether, "addr2 should have 50 tokens");
    }

    function testFailTransferMoreThanBalance() public {
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vm.prank(owner); // Set msg.sender to owner
        erc20F.transfer(addr1, 2000 ether); // This should fail
    }

    function testStakeTokens() public {
        vm.prank(owner);
        erc20F.stakeTokens(50 ether);

        uint256 stakedAmount = erc20F.stakedAmount();
        assertEq(stakedAmount, 50 ether, "Staked amount should be 500 tokens");
    }

    function testViewReward() public {
        vm.prank(owner);
        erc20F.stakeTokens(500 ether);

        // Fast forward time by 1 year (365 days)
        vm.warp(block.timestamp + 365 days);

        uint256 reward = erc20F.viewReward();

        assertEq(reward, 25 ether, "Reward should be 25 tokens after 1 year");
    }

    function testUnstakeTokens() public {
        vm.prank(owner);
        erc20F.stakeTokens(500 ether);

        vm.warp(block.timestamp + 365 days);
        erc20F.unstakeTokens();

        uint256 ownerBalance = erc20F.balanceOf(owner);

        assertEq(ownerBalance, 525 ether, "Owner balance should be 525 tokens after unstaking");
    }

    function testStakeAndUnstakeMultipleTimes() public {
        vm.prank(owner);
        erc20F.stakeTokens(300 ether);

        vm.warp(block.timestamp + 180 days);
        erc20F.stakeTokens(200 ether);

        vm.warp(block.timestamp + 180 days);

        erc20F.unstakeTokens();

        uint256 ownerBalance = erc20F.balanceOf(owner);

        // Calculated expected reward:
        // - First 300 tokens staked for 360 days
        // - Second 200 tokens staked for 180 days
        // Total reward is approximately 22.47 ether
        assertEq(ownerBalance, 522.47 ether, "Owner balance should reflect the correct staking rewards");
    }

    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external override {}
}
