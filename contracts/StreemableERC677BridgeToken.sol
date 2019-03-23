pragma solidity ^0.4.24;
import "./IBurnableMintableERC677Token.sol";
import "./ERC677Receiver.sol";
import "./StreemableERC20Token.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

contract StreemableERC677BridgeToken is
	IBurnableMintableERC677Token,
	StreemableERC20Token,
	Ownable
{

	address public bridgeContract;

	event ContractFallbackCallFailed(address from, address to, uint value);

	modifier validRecipient(address _recipient) {
		require(_recipient != address(0) && _recipient != address(this));
		_;
	}

	constructor(string _name, string _symbol, uint8 _decimals)
		public
		StreemableERC20Token(_name, _symbol, _decimals)
	{}

	function setBridgeContract(address _bridgeContract)
		onlyOwner
		public
	{
		require(_bridgeContract != address(0) && isContract(_bridgeContract));
		bridgeContract = _bridgeContract;
	}

	/// ERC677 transfer which invokes a callback if the receiver is a contract
	/// fails if the callback doesn't succeed
	function transferAndCall(address _to, uint _value, bytes _data)
		external
		validRecipient(_to)
		returns (bool)
	{
		require(superTransfer(_to, _value));
		// ERC677 specific transfer event
		emit Transfer(msg.sender, _to, _value, _data);

		if (isContract(_to)) {
			require(contractFallback(_to, _value, _data));
		}
		return true;
	}

	function getTokenInterfacesVersion()
		public
		pure
		returns(uint64 major, uint64 minor, uint64 patch)
	{
		return (2, 0, 0);
	}

	function superTransfer(address _to, uint256 _value)
		internal
		returns(bool)
	{
		return super.transfer(_to, _value);
	}

	/// ERC677 transfer which invokes a callback if the receiver is a contract
	//	Doesn't fail if the callback doesn't succeed (unless it's the bridge contract)
	function transfer(address _to, uint256 _value)
		public
		returns (bool)
	{
		require(superTransfer(_to, _value));
		if (isContract(_to) && !contractFallback(_to, _value, new bytes(0))) {
			if (_to == bridgeContract) {
				revert();
			} else {
				emit ContractFallbackCallFailed(msg.sender, _to, _value);
			}
		}
		return true;
	}

	/// not sure why they named this "fallback", wouldn't "callback be more appropriate?
	function contractFallback(address _to, uint _value, bytes _data)
		private
		returns(bool)
	{
		return _to.call(abi.encodeWithSignature("onTokenTransfer(address,uint256,bytes)",  msg.sender, _value, _data));
	}

	function isContract(address _addr)
		private
		view
		returns (bool)
	{
		uint length;
		assembly { length := extcodesize(_addr) }
		return length > 0;
	}

	function renounceOwnership()
		public
		onlyOwner
	{
		revert();
	}

	/// avoids ETH and arbitrary 3rd party tokens ending up being owner by this contract (for whatever reason)
	/// to remain stuck in Nirvana. This allows the contract owner to transfer them somewhere.
	function claimTokens(address _token, address _to)
		public
		onlyOwner
	{
		require(_to != address(0));
		if (_token == address(0)) {
			_to.transfer(address(this).balance);
			return;
		}

		ERC20 token = ERC20(_token);
		uint256 balance = token.balanceOf(address(this));
		require(token.transfer(_to, balance));
	}

	// ***************** BURNABLE *****************

	event Burn(address indexed burner, uint256 value);

	/**
     * @dev Burns a specific amount of tokens.
     * @param _value The amount of token to be burned.
     */
	function burn(uint256 _value) public {
		_burn(msg.sender, _value);
	}

	function _burn(address _who, uint256 _value) internal {
		require(_value <= balanceOf(_who));
		staticBalances[_who] -= int(_value);
		totalSupply -= _value;
		emit Burn(_who, _value);
		emit Transfer(_who, address(0), _value);
	}

	// ***************** MINTABLE *****************

	event Mint(address indexed to, uint256 amount);
	event MintFinished();

	bool public mintingFinished = false;


	modifier canMint() {
		require(!mintingFinished);
		_;
	}

	modifier hasMintPermission() {
		require(msg.sender == owner);
		_;
	}

	/**
     * @dev Function to mint tokens
     * @param _to The address that will receive the minted tokens.
     * @param _amount The amount of tokens to mint.
     * @return A boolean that indicates if the operation was successful.
     */
	function mint(
		address _to,
		uint256 _amount
	)
		hasMintPermission
		canMint
		public
		returns (bool)
	{
		uint256 newTotalSupply = totalSupply + _amount;
		// this should avoid overflows and underflows caused by internal usage of int256
		// TODO: check if this does really what's intended (and isn't optimized away or so...)
		require(uint(int(newTotalSupply)) > totalSupply, "int overflow");

		totalSupply += _amount;
		staticBalances[_to] += int(_amount);
		emit Mint(_to, _amount);
		emit Transfer(address(0), _to, _amount);
		return true;
	}

	/* finishMinting() not added, because it's disabled (reverts) in ERC677BridgeToken */
}
