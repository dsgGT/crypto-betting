// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/WagerManager.sol";

/**
 * @dev Foundry tests for both “private” and “open-seat” wager flows.
 *      Dummy 65-byte signatures satisfy the length check; we don’t verify
 *      signer addresses in these unit tests.
 */
contract WagerTest is Test {
    /* ─── Test actors ─────────────────────────────────────────────── */
    address creator  = vm.addr(1);
    address opponent = vm.addr(2);
    address stranger = vm.addr(3);   // anyone / attestor rôle

    /* ─── Constants ───────────────────────────────────────────────── */
    uint64  stake  = 0.1 ether;
    uint40  expiry = uint40(block.timestamp + 2 days);

    /* ─── System under test ───────────────────────────────────────── */
    WagerManager wager;

    /* ─── Sig helpers (two distinct 65-byte blobs) ────────────────── */
    bytes[] sigs;
    uint256 constant ATTESTOR_1_PK = 0x123;
    uint256 constant ATTESTOR_2_PK = 0x456;
    address attestor1;
    address attestor2;

    function setUp() public {
        wager = new WagerManager();

        // Setup attestor addresses
        attestor1 = vm.addr(ATTESTOR_1_PK);
        attestor2 = vm.addr(ATTESTOR_2_PK);

        // Fund test addresses with ETH
        vm.deal(creator, 10 ether);
        vm.deal(opponent, 10 ether);
        vm.deal(stranger, 10 ether);

        // Initialize signatures array
        sigs = new bytes[](2);
    }

    function _createValidSignatures(uint256 id, bytes32 payload) internal {
        // Recreate the same digest that _verifyThreshold creates
        bytes32 EIP712_DOMAIN = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("CheckmateArena"),
                keccak256("1"),
                block.chainid,
                address(wager)
            )
        );
        
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", EIP712_DOMAIN, keccak256(abi.encode(id, payload)))
        );

        // Create valid signatures
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(ATTESTOR_1_PK, digest);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(ATTESTOR_2_PK, digest);

        sigs[0] = abi.encodePacked(r1, s1, v1);
        sigs[1] = abi.encodePacked(r2, s2, v2);
    }

    /*────────────────────────────────────────────────────────────────*/
    /*                     PRIVATE-MATCH HAPPY PATH                   */
    /*────────────────────────────────────────────────────────────────*/
    function test_PrivateMatchFlow() public {
        // 1. creator opens with explicit opponent
        vm.prank(creator);
        wager.createMatch{value: stake}(opponent, expiry);

        // 2. opponent funds
        vm.prank(opponent);
        wager.fundMatch{value: stake}(1);

        // 3. attestors pin result
        bytes32 gameHash = keccak256("dummyGameHash");
        _createValidSignatures(1, gameHash);
        vm.prank(stranger);
        wager.pinResult(1, gameHash, sigs);

        // 4. attestors settle to opponent
        _createValidSignatures(1, bytes32(uint256(uint160(opponent))));
        vm.prank(stranger);
        wager.settle(1, opponent, sigs);

        // 5. pot paid (2 × stake)
        // opponent started with 10 ether, spent 0.1 ether on bet, won 0.2 ether
        assertEq(opponent.balance, 10 ether - stake + (stake * 2));
    }

    /*────────────────────────────────────────────────────────────────*/
    /*                     OPEN-SEAT  FLOW                            */
    /*────────────────────────────────────────────────────────────────*/
    function test_OpenMatch_FirstFunderClaimsSeat() public {
        // 1. creator leaves seat open (opponent = 0x0)
        vm.prank(creator);
        wager.createMatch{value: stake}(address(0), expiry);

        // 2. stranger funds first → becomes opponent
        vm.prank(stranger);
        wager.fundMatch{value: stake}(1);

        (, address recordedOpponent,,,,,) = wager.matches(1);
        assertEq(recordedOpponent, stranger);
    }

    function test_OpenMatch_SecondFunderReverts() public {
        vm.prank(creator);
        wager.createMatch{value: stake}(address(0), expiry);

        // first funder claims seat
        vm.prank(stranger);
        wager.fundMatch{value: stake}(1);

        // second funder should fail
        vm.expectRevert(WagerManager.AlreadyFunded.selector);
        vm.prank(opponent);
        wager.fundMatch{value: stake}(1);
    }

    /*────────────────────────────────────────────────────────────────*/
    /*                     REFUND PATH                               */
    /*────────────────────────────────────────────────────────────────*/
    function test_RefundAfterExpiry() public {
        vm.prank(creator);
        wager.createMatch{value: stake}(opponent, uint40(block.timestamp + 1));

        // opponent funds before expiry
        vm.prank(opponent);
        wager.fundMatch{value: stake}(1);

        // warp past expiry
        vm.warp(block.timestamp + 2);

        uint256 creatorBalanceBefore = creator.balance;
        uint256 opponentBalanceBefore = opponent.balance;

        vm.prank(creator);
        wager.refund(1);

        // Both parties get their stake back
        assertEq(creator.balance, creatorBalanceBefore + stake);
        assertEq(opponent.balance, opponentBalanceBefore + stake);
    }
}