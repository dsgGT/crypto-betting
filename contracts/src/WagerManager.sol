// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/**
 * @title WagerManager
 * @notice   • “Private” wager  →  creator passes opponent address
 *           • “Open”   wager   →  creator passes address(0); first funder claims the seat
 */
contract WagerManager is ReentrancyGuard {
    /*────────────────── CONFIG ──────────────────*/
    uint8  public constant SIG_THRESHOLD = 2;
    bytes32 private immutable EIP712_DOMAIN;
    
    constructor() {
        EIP712_DOMAIN = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes("CheckmateArena")),   // name
                keccak256(bytes("1")),                // version
                block.chainid,                        // runtime chainId
                address(this)                         // contract address
            )
        );
    }

    /*────────────────── STORAGE ──────────────────*/
    enum Status {Created, Funded, Pinned, Settled, Refunded}

    struct Match {
        address creator;
        address opponent;   // can start as 0x0
        uint64  stake;
        bytes32 gameHash;
        uint40  tCreated;
        uint40  tExpiry;
        Status  status;
    }

    uint256 public nextId = 1;
    mapping(uint256 => Match) public matches;
    mapping(bytes32 => bool)  public usedSig;   // replay-blocklist

    /*────────────────── ERRORS ───────────────────*/
    error StakeMismatch();
    error AlreadyFunded();
    error NotOpponent();
    error SeatTaken();
    error InvalidSig();
    error TooEarly();
    error TooLate();
    error AlreadySettled();

    /*────────────────── EVENTS ───────────────────*/
    event MatchCreated (uint256 id, address indexed creator, address indexed opponent, uint64 stake);
    event MatchFunded  (uint256 id, address indexed opponent);
    event MatchPinned  (uint256 id, bytes32 gameHash);
    event MatchSettled (uint256 id, address indexed winner);
    event MatchRefunded(uint256 id);

    /*───────────────── CREATE ──────────────────*/
    /**
     * @param opponent Pass address(0) to create an *open* challenge.
     * @param tExpiry  Absolute timestamp after which refund is allowed.
     */
    function createMatch(address opponent, uint40 tExpiry)
        external payable nonReentrant
    {
        uint64 stake = uint64(msg.value);
        uint256 id   = nextId++;

        matches[id] = Match({
            creator:  msg.sender,
            opponent: opponent,      // 0x0  ⇒  open seat
            stake:    stake,
            gameHash: 0,
            tCreated: uint40(block.timestamp),
            tExpiry:  tExpiry,
            status:   Status.Created
        });

        emit MatchCreated(id, msg.sender, opponent, stake);
    }

    /*────────────────── FUND ───────────────────*/
    function fundMatch(uint256 id) external payable nonReentrant {
        Match storage m = matches[id];

        if (m.status != Status.Created)                    revert AlreadyFunded();
        if (msg.value != m.stake)                          revert StakeMismatch();

        if (m.opponent == address(0)) {
            // OPEN CHALLENGE — first funder claims the seat
            if (msg.sender == m.creator)                   revert NotOpponent();
            m.opponent = msg.sender;
        } else {
            // PRIVATE CHALLENGE — must be invited opponent
            if (msg.sender != m.opponent)                  revert SeatTaken();
        }

        m.status = Status.Funded;
        emit MatchFunded(id, m.opponent);
    }

    /*────────────────── PIN ───────────────────*/
    function pinResult(
        uint256 id,
        bytes32 gameHash,
        bytes[] calldata sigs
    ) external {
        Match storage m = matches[id];
        if (m.status != Status.Funded) revert TooEarly();

        _verifyThreshold(id, gameHash, sigs);

        m.gameHash = gameHash;
        m.status   = Status.Pinned;
        emit MatchPinned(id, gameHash);
    }

    /*────────────────── SETTLE ─────────────────*/
    function settle(
        uint256 id,
        address winner,
        bytes[] calldata sigs
    ) external nonReentrant {
        Match storage m = matches[id];
        if (m.status != Status.Pinned) revert TooEarly();

        _verifyThreshold(id, bytes32(uint256(uint160(winner))), sigs);

        m.status = Status.Settled;
        (bool ok, ) = winner.call{value: m.stake * 2}("");
        require(ok, "transfer fail");

        emit MatchSettled(id, winner);
    }

    /*────────────────── REFUND ─────────────────*/
    function refund(uint256 id) external nonReentrant {
        Match storage m = matches[id];
        if (block.timestamp <= m.tExpiry)                   revert TooEarly();
        if (m.status != Status.Created && m.status != Status.Funded)
            revert AlreadySettled();

        m.status = Status.Refunded;
        _payoutHalf(m.creator,  m.stake);
        if (m.opponent != address(0)) _payoutHalf(m.opponent, m.stake);

        emit MatchRefunded(id);
    }

    /*────────────────── HELPERS ────────────────*/
    function _payoutHalf(address to, uint256 amt) private {
        (bool ok, ) = to.call{value: amt}("");
        require(ok, "transfer fail");
    }

    function _verifyThreshold(
        uint256 id,
        bytes32 payload,
        bytes[] calldata sigs
    ) private {
        if (sigs.length < SIG_THRESHOLD) revert InvalidSig();

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", EIP712_DOMAIN, keccak256(abi.encode(id, payload)))
        );

        uint8 counted;
        for (uint256 i; i < sigs.length; ++i) {
            address signer = ECDSA.recover(digest, sigs[i]);
            bytes32 sigHash = keccak256(sigs[i]);
            if (!usedSig[sigHash]) {
                usedSig[sigHash] = true;
                ++counted;
            }
        }
        if (counted < SIG_THRESHOLD) revert InvalidSig();
    }
}