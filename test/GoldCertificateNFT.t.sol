// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {GoldCertificateNFT} from "../src/GoldCertificateNFT.sol";

contract NFTReceiver is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract GoldCertificateNFTTest is Test {
    GoldCertificateNFT public nft;
    NFTReceiver public receiver;

    address public admin = address(1);
    address public minter = address(2);
    address public pauser = address(3);
    address public user = address(4);
    address public attacker = address(5);

    uint256 public constant GOLD_AMOUNT = 100 ether;

    function setUp() public {
        nft = new GoldCertificateNFT(admin);
        receiver = new NFTReceiver();

        vm.startPrank(admin);
        nft.grantRole(nft.MINTER_ROLE(), minter);
        nft.grantRole(nft.PAUSER_ROLE(), pauser);
        vm.stopPrank();
    }

    function testConstructorSetsNameSymbolAndRoles() public view {
        assertEq(nft.name(), "GoldVault Certificate");
        assertEq(nft.symbol(), "GVCERT");
        assertTrue(nft.hasRole(nft.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(nft.hasRole(nft.PAUSER_ROLE(), admin));
    }

    function testConstructorRevertsWithZeroAdmin() public {
        vm.expectRevert(GoldCertificateNFT.ZeroAddress.selector);
        new GoldCertificateNFT(address(0));
    }

    function testMinterCanMintCertificate() public {
        vm.warp(1000);

        vm.prank(minter);
        uint256 tokenId = nft.mint(user, GOLD_AMOUNT);

        assertEq(tokenId, 0);
        assertEq(nft.ownerOf(tokenId), user);
        assertEq(nft.balanceOf(user), 1);
        assertEq(nft.totalSupply(), 1);

        (uint256 goldAmountWei, uint256 issuedAt, address issuer) = nft.certificates(tokenId);

        assertEq(goldAmountWei, GOLD_AMOUNT);
        assertEq(issuedAt, 1000);
        assertEq(issuer, minter);
    }

    function testMintToContractReceiver() public {
        vm.prank(minter);
        uint256 tokenId = nft.mint(address(receiver), GOLD_AMOUNT);

        assertEq(nft.ownerOf(tokenId), address(receiver));
    }

    function testNonMinterCannotMint() public {
        vm.prank(attacker);
        vm.expectRevert();
        nft.mint(user, GOLD_AMOUNT);
    }

    function testMintRevertsWithZeroAddress() public {
        vm.prank(minter);
        vm.expectRevert(GoldCertificateNFT.ZeroAddress.selector);
        nft.mint(address(0), GOLD_AMOUNT);
    }

    function testMintRevertsWithZeroAmount() public {
        vm.prank(minter);
        vm.expectRevert(GoldCertificateNFT.ZeroAmount.selector);
        nft.mint(user, 0);
    }

    function testMinterCanBurnCertificate() public {
        vm.prank(minter);
        uint256 tokenId = nft.mint(user, GOLD_AMOUNT);

        vm.prank(minter);
        nft.burn(tokenId);

        assertEq(nft.balanceOf(user), 0);
        assertEq(nft.totalSupply(), 0);

        (uint256 goldAmountWei, uint256 issuedAt, address issuer) = nft.certificates(tokenId);

        assertEq(goldAmountWei, 0);
        assertEq(issuedAt, 0);
        assertEq(issuer, address(0));
    }

    function testNonMinterCannotBurn() public {
        vm.prank(minter);
        uint256 tokenId = nft.mint(user, GOLD_AMOUNT);

        vm.prank(attacker);
        vm.expectRevert();
        nft.burn(tokenId);
    }

    function testBurnRevertsForNonexistentToken() public {
        vm.prank(minter);
        vm.expectRevert();
        nft.burn(999);
    }

    function testUserCanTransferWhenNotPaused() public {
        vm.prank(minter);
        uint256 tokenId = nft.mint(user, GOLD_AMOUNT);

        vm.prank(user);
        nft.transferFrom(user, attacker, tokenId);

        assertEq(nft.ownerOf(tokenId), attacker);
    }

    function testPauserCanPauseAndUnpause() public {
        vm.prank(pauser);
        nft.pause();

        assertTrue(nft.paused());

        vm.prank(pauser);
        nft.unpause();

        assertFalse(nft.paused());
    }

    function testNonPauserCannotPause() public {
        vm.prank(attacker);
        vm.expectRevert();
        nft.pause();
    }

    function testMintRevertsWhenPaused() public {
        vm.prank(pauser);
        nft.pause();

        vm.prank(minter);
        vm.expectRevert();
        nft.mint(user, GOLD_AMOUNT);
    }

    function testTransferRevertsWhenPaused() public {
        vm.prank(minter);
        uint256 tokenId = nft.mint(user, GOLD_AMOUNT);

        vm.prank(pauser);
        nft.pause();

        vm.prank(user);
        vm.expectRevert();
        nft.transferFrom(user, attacker, tokenId);
    }

    function testSupportsInterfaces() public view {
        assertTrue(nft.supportsInterface(0x01ffc9a7));
        assertTrue(nft.supportsInterface(0x80ac58cd));
        assertTrue(nft.supportsInterface(0x780e9d63));
    }
}
