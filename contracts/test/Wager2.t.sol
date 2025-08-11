// test/Wager2.t.sol
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/WagerManager.sol";

contract WagerTest is Test {
    WagerManager public wager;

    address public player1 = address(1);
    address public player2 = address(2);

    function setUp() public {
        wager = new WagerManager();
        vm.deal(player1, 10 ether); // Give test ETH to player1
        vm.deal(player2, 10 ether); // Give test ETH to player2
    }

    function testEmitMatchFunded() public {
        uint40 expiry = uint40(block.timestamp + 1 hours);
        
        // Step 1: Player1 creates a match
        vm.startPrank(player1);
        wager.createMatch{value: 1 ether}(player2, expiry);
        vm.stopPrank();

        // Step 2: Player2 funds the match
        vm.startPrank(player2);
        
        // Expect the MatchFunded event to be emitted
        vm.expectEmit(true, true, false, true);
        emit WagerManager.MatchFunded(1, player2);
        
        wager.fundMatch{value: 1 ether}(1);
        
        vm.stopPrank();

        // Verify the match is now in Funded status (status = 1)
        (, , , , , , WagerManager.Status status) = wager.matches(1);
        assertEq(uint8(status), 1, "Match should be in Funded status");
    }
}