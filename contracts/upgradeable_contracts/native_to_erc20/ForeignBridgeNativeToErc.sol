pragma solidity 0.4.24;
import "../../libraries/SafeMath.sol";
import "../BasicBridge.sol";
import "../../IBurnableMintableERC677Token.sol";
import "../../ERC677Receiver.sol";
import "../BasicForeignBridge.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Basic.sol";
import "../ERC677Bridge.sol";


contract ForeignBridgeNativeToErc is ERC677Receiver, BasicBridge, BasicForeignBridge, ERC677Bridge {

    /// Event created on money withdraw.
    event UserRequestForAffirmation(address recipient, uint256 value);
    event FeeWithdrawal(uint256 amount);

    function initialize(
        address _validatorContract,
        address _erc677token,
        uint256 _dailyLimit,
        uint256 _maxPerTx,
        uint256 _minPerTx,
        uint256 _foreignGasPrice,
        uint256 _requiredBlockConfirmations,
        uint256 _homeDailyLimit,
        uint256 _homeMaxPerTx,
        address _owner
    ) public returns(bool) {
        require(!isInitialized());
        require(_validatorContract != address(0) && isContract(_validatorContract));
        require(_minPerTx > 0 && _maxPerTx > _minPerTx && _dailyLimit > _maxPerTx);
        require(_foreignGasPrice > 0);
        require(_homeMaxPerTx < _homeDailyLimit);
        require(_owner != address(0));
        addressStorage[keccak256(abi.encodePacked("validatorContract"))] = _validatorContract;
        setErc677token(_erc677token);
        uintStorage[keccak256(abi.encodePacked("dailyLimit"))] = _dailyLimit;
        uintStorage[keccak256(abi.encodePacked("deployedAtBlock"))] = block.number;
        uintStorage[keccak256(abi.encodePacked("maxPerTx"))] = _maxPerTx;
        uintStorage[keccak256(abi.encodePacked("minPerTx"))] = _minPerTx;
        uintStorage[keccak256(abi.encodePacked("gasPrice"))] = _foreignGasPrice;
        uintStorage[keccak256(abi.encodePacked("requiredBlockConfirmations"))] = _requiredBlockConfirmations;
        uintStorage[keccak256(abi.encodePacked("executionDailyLimit"))] = _homeDailyLimit;
        uintStorage[keccak256(abi.encodePacked("executionMaxPerTx"))] = _homeMaxPerTx;
        setOwner(_owner);
        setInitialize(true);
        return isInitialized();
    }

    function executeSignaturesRecipientPays(uint8[] vs, bytes32[] rs, bytes32[] ss, bytes message) external {
        Message.hasEnoughValidSignatures(message, vs, rs, ss, validatorContract());
        address recipient = processMessage(message);

        // check if recipient has enough deposits
        uint256 chargedFee = tx.gasprice * 200000; // 200k gas should always be enough for this tx
        require(uintStorage[keccak256(abi.encodePacked("feeDeposits", recipient))] >= chargedFee, "not enough fee deposits");
        // take from fee deposits
        uintStorage[keccak256(abi.encodePacked("feeDeposits", recipient))] -= chargedFee;
        uintStorage[keccak256(abi.encodePacked("feeDeposits", owner()))] += chargedFee;

        /*
         * In case of an Exception in processMessage(), the recipient won't be charged for the failed tx.
         * This is on purpose. It's the relayer's responsibility to check if the tx would succeed before broadcasting it.
         * The recipient could game the relayer by having a fee deposit withdrawal tx race against the relay tx.
         * However there's no economic incentive to do so (relay tx would fail), thus this risk for the relayer
         * looks acceptable.
         */
    }

    function withdrawCollectedFees() external onlyIfOwnerOfProxy {
        uint256 amount = uintStorage[keccak256(abi.encodePacked("feeDeposits", owner()))];
        require(amount > 0, "nothing to claim");
        uintStorage[keccak256(abi.encodePacked("feeDeposits", owner()))] = 0;
        emit FeeWithdrawal(amount);
        msg.sender.transfer(amount); // throws on failure
    }

    function getBridgeMode() public pure returns(bytes4 _data) {
        return bytes4(keccak256(abi.encodePacked("native-to-erc-core")));
    }

    function claimTokensFromErc677(address _token, address _to) external onlyIfOwnerOfProxy {
        erc677token().claimTokens(_token, _to);
    }

    function onExecuteMessage(address _recipient, uint256 _amount) internal returns(bool){
        setTotalExecutedPerDay(getCurrentDay(), totalExecutedPerDay(getCurrentDay()).add(_amount));
        return erc677token().mint(_recipient, _amount);
    }

    function fireEventOnTokenTransfer(address _from, uint256 _value) internal {
        emit UserRequestForAffirmation(_from, _value);
    }

    function messageWithinLimits(uint256 _amount) internal view returns(bool) {
        return withinExecutionLimit(_amount);
    }

    function onFailedMessage(address, uint256, bytes32) internal {
        revert();
    }
}
