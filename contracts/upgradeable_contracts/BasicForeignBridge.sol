pragma solidity 0.4.24;

import "../upgradeability/EternalStorage.sol";
import "../libraries/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Basic.sol";
import "./Validatable.sol";
import "../libraries/Message.sol";

contract BasicForeignBridge is EternalStorage, Validatable {
    using SafeMath for uint256;
    /// triggered when relay of deposit from HomeBridge is complete
    event RelayedMessage(address recipient, uint value, bytes32 transactionHash);

    /// Anybody can relay a task from the home chain. All required proof is contained in the signatures
    function executeSignatures(uint8[] vs, bytes32[] rs, bytes32[] ss, bytes message) external {
        Message.hasEnoughValidSignatures(message, vs, rs, ss, validatorContract());
        processMessage(message);
    }

    function processMessage(bytes message) internal returns(address) {
        address recipient;
        uint256 amount;
        bytes32 txHash;
        address contractAddress;
        (recipient, amount, txHash, contractAddress) = Message.parseMessage(message);
        if (messageWithinLimits(amount)) {
            require(contractAddress == address(this));
            require(!relayedMessages(txHash));
            setRelayedMessages(txHash, true);
            require(onExecuteMessage(recipient, amount));
            emit RelayedMessage(recipient, amount, txHash);
        } else {
            onFailedMessage(recipient, amount, txHash);
        }
        return recipient;
    }

    function () payable public {
        if(msg.value > 0) {
            addFeeDepositFor(msg.sender);
        } else {
            withdrawFeeDeposit();
        }
    }

    function addFeeDepositFor(address addr) payable public {
        uintStorage[keccak256(abi.encodePacked("feeDeposits", addr))] += msg.value;
    }

    function withdrawFeeDeposit() public {
        uint256 withdrawAmount = uintStorage[keccak256(abi.encodePacked("feeDeposits", msg.sender))];
        require(withdrawAmount > 0, "no fee deposits");
        delete uintStorage[keccak256(abi.encodePacked("feeDeposits", msg.sender))]; // implies setting the value to 0
        msg.sender.transfer(withdrawAmount); // throws on failure
    }

    /// convenience method for checking current deposits of a given address
    function feeDepositOf(address addr) public view returns(uint256) {
        return uintStorage[keccak256(abi.encodePacked("feeDeposits", addr))];
    }

    function onExecuteMessage(address, uint256) internal returns(bool);

    function setRelayedMessages(bytes32 _txHash, bool _status) internal {
        boolStorage[keccak256(abi.encodePacked("relayedMessages", _txHash))] = _status;
    }

    function relayedMessages(bytes32 _txHash) public view returns(bool) {
        return boolStorage[keccak256(abi.encodePacked("relayedMessages", _txHash))];
    }

    function messageWithinLimits(uint256) internal view returns(bool);

    function onFailedMessage(address, uint256, bytes32) internal;
}
