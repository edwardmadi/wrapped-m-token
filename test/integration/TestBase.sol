// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";
import { IERC20Extended } from "../../lib/common/src/interfaces/IERC20Extended.sol";
import { IERC712 } from "../../lib/common/src/interfaces/IERC712.sol";

import { Proxy } from "../../lib/common/src/Proxy.sol";
import { Test } from "../../lib/forge-std/src/Test.sol";

import { ISmartMToken } from "../../src/interfaces/ISmartMToken.sol";

import { EarnerManager } from "../../src/EarnerManager.sol";
import { SmartMToken } from "../../src/SmartMToken.sol";
import { SmartMTokenMigratorV1 } from "../../src/SmartMTokenMigratorV1.sol";

import { IMTokenLike, IRegistrarLike } from "./vendor/protocol/Interfaces.sol";

contract TestBase is Test {
    IMTokenLike internal constant _mToken = IMTokenLike(0x866A2BF4E572CbcF37D5071A7a58503Bfb36be1b);

    address internal constant _minterGateway = 0xf7f9638cb444D65e5A40bF5ff98ebE4ff319F04E;
    address internal constant _registrar = 0x119FbeeDD4F4f4298Fb59B720d5654442b81ae2c;
    address internal constant _excessDestination = 0xd7298f620B0F752Cf41BD818a16C756d9dCAA34f; // vault
    address internal constant _standardGovernor = 0xB024aC5a7c6bC92fbACc8C3387E628a07e1Da016;
    address internal constant _mSource = 0x563AA56D0B627d1A734e04dF5762F5Eea1D56C2f;
    address internal constant _wmSource = 0xfE940BFE535013a52e8e2DF9644f95E3C94fa14B;

    ISmartMToken internal constant _smartMToken = ISmartMToken(0x437cc33344a0B27A429f795ff6B469C72698B291);

    bytes32 internal constant _EARNERS_LIST = "earners";
    bytes32 internal constant _MIGRATOR_V1_PREFIX = "wm_migrator_v1";
    bytes32 internal constant _CLAIM_OVERRIDE_RECIPIENT_PREFIX = "wm_claim_override_recipient";
    bytes32 internal constant _EARNER_STATUS_ADMIN_LIST = "wm_earner_status_admins";

    // USDC on Ethereum Mainnet
    address internal constant _USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // Large USDC holder on Ethereum Mainnet
    address internal constant _USDC_SOURCE = 0x4B16c5dE96EB2117bBE5fd171E4d203624B014aa;

    // DAI on Ethereum Mainnet
    address internal constant _DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    // Large DAI holder on Ethereum Mainnet
    address internal constant _DAI_SOURCE = 0xD1668fB5F690C59Ab4B0CAbAd0f8C1617895052B;

    address internal _migrationAdmin = 0x431169728D75bd02f4053435b87D15c8d1FB2C72;

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    address internal _carol = makeAddr("carol");
    address internal _dave = makeAddr("dave");
    address internal _eric = makeAddr("eric");
    address internal _frank = makeAddr("frank");
    address internal _grace = makeAddr("grace");
    address internal _henry = makeAddr("henry");
    address internal _ivan = makeAddr("ivan");
    address internal _judy = makeAddr("judy");

    uint256 internal _aliceKey = _makeKey("alice");

    address[] internal _accounts = [_alice, _bob, _carol, _dave, _eric, _frank, _grace, _henry, _ivan, _judy];

    address internal _earnerManagerImplementation;
    address internal _earnerManager;
    address internal _smartMTokenImplementationV2;
    address internal _smartMTokenMigratorV1;

    function _getSource(address token_) internal pure returns (address source_) {
        if (token_ == _USDC) return _USDC_SOURCE;

        if (token_ == _DAI) return _DAI_SOURCE;

        revert();
    }

    function _give(address token_, address account_, uint256 amount_) internal {
        vm.prank(_getSource(token_));
        IERC20(token_).transfer(account_, amount_);
    }

    function _addToList(bytes32 list_, address account_) internal {
        vm.prank(_standardGovernor);
        IRegistrarLike(_registrar).addToList(list_, account_);
    }

    function _removeFomList(bytes32 list_, address account_) internal {
        vm.prank(_standardGovernor);
        IRegistrarLike(_registrar).removeFromList(list_, account_);
    }

    function _giveM(address account_, uint256 amount_) internal {
        vm.prank(_mSource);
        _mToken.transfer(account_, amount_);
    }

    function _giveWM(address account_, uint256 amount_) internal {
        vm.prank(_wmSource);
        _smartMToken.transfer(account_, amount_);
    }

    function _giveEth(address account_, uint256 amount_) internal {
        vm.deal(account_, amount_);
    }

    function _wrap(address account_, address recipient_, uint256 amount_) internal {
        vm.prank(account_);
        _mToken.approve(address(_smartMToken), amount_);

        vm.prank(account_);
        _smartMToken.wrap(recipient_, amount_);
    }

    function _wrap(address account_, address recipient_) internal {
        vm.prank(account_);
        _mToken.approve(address(_smartMToken), type(uint256).max);

        vm.prank(account_);
        _smartMToken.wrap(recipient_);
    }

    function _wrapWithPermitVRS(
        address account_,
        uint256 signerPrivateKey_,
        address recipient_,
        uint256 amount_,
        uint256 nonce_,
        uint256 deadline_
    ) internal {
        (uint8 v_, bytes32 r_, bytes32 s_) = _getPermit(account_, signerPrivateKey_, amount_, nonce_, deadline_);

        vm.prank(account_);
        _smartMToken.wrapWithPermit(recipient_, amount_, deadline_, v_, r_, s_);
    }

    function _wrapWithPermitSignature(
        address account_,
        uint256 signerPrivateKey_,
        address recipient_,
        uint256 amount_,
        uint256 nonce_,
        uint256 deadline_
    ) internal {
        (uint8 v_, bytes32 r_, bytes32 s_) = _getPermit(account_, signerPrivateKey_, amount_, nonce_, deadline_);

        vm.prank(account_);
        _smartMToken.wrapWithPermit(recipient_, amount_, deadline_, abi.encodePacked(r_, s_, v_));
    }

    function _unwrap(address account_, address recipient_, uint256 amount_) internal {
        vm.prank(account_);
        _smartMToken.unwrap(recipient_, amount_);
    }

    function _unwrap(address account_, address recipient_) internal {
        vm.prank(account_);
        _smartMToken.unwrap(recipient_);
    }

    function _transferWM(address sender_, address recipient_, uint256 amount_) internal {
        vm.prank(sender_);
        _smartMToken.transfer(recipient_, amount_);
    }

    function _approveWM(address account_, address spender_, uint256 amount_) internal {
        vm.prank(account_);
        _smartMToken.approve(spender_, amount_);
    }

    function _set(bytes32 key_, bytes32 value_) internal {
        vm.prank(_standardGovernor);
        IRegistrarLike(_registrar).setKey(key_, value_);
    }

    function _setClaimOverrideRecipient(address account_, address recipient_) internal {
        _set(keccak256(abi.encode(_CLAIM_OVERRIDE_RECIPIENT_PREFIX, account_)), bytes32(uint256(uint160(recipient_))));
    }

    function _deployV2Components() internal {
        _earnerManagerImplementation = address(new EarnerManager(_registrar, _migrationAdmin));
        _earnerManager = address(new Proxy(_earnerManagerImplementation));
        _smartMTokenImplementationV2 = address(
            new SmartMToken(address(_mToken), _registrar, _earnerManager, _excessDestination, _migrationAdmin)
        );
        _smartMTokenMigratorV1 = address(new SmartMTokenMigratorV1(_smartMTokenImplementationV2));
    }

    function _migrate() internal {
        _set(
            keccak256(abi.encode(_MIGRATOR_V1_PREFIX, address(_smartMToken))),
            bytes32(uint256(uint160(_smartMTokenMigratorV1)))
        );

        _smartMToken.migrate();
    }

    function _migrateFromAdmin() internal {
        vm.prank(_migrationAdmin);
        _smartMToken.migrate(_smartMTokenMigratorV1);
    }

    /* ============ utils ============ */

    function _makeKey(string memory name_) internal returns (uint256 key_) {
        (, key_) = makeAddrAndKey(name_);
    }

    function _getPermit(
        address account_,
        uint256 signerPrivateKey_,
        uint256 amount_,
        uint256 nonce_,
        uint256 deadline_
    ) internal view returns (uint8 v_, bytes32 r_, bytes32 s_) {
        return
            vm.sign(
                signerPrivateKey_,
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        IERC712(address(_mToken)).DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                IERC20Extended(address(_mToken)).PERMIT_TYPEHASH(),
                                account_,
                                address(_smartMToken),
                                amount_,
                                nonce_,
                                deadline_
                            )
                        )
                    )
                )
            );
    }
}
