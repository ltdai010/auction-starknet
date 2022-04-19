# Declare this file as a StarkNet contract and set the required
# builtins.
%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.messages import send_message_to_l1
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_not_zero

const BRIDGE_MODE_WITHDRAW = 1

@contract_interface
namespace IBridgedERC20:
    func create_token(owner : felt, amount : felt):
    end

    func delete_token(owner : felt, amount : felt):
    end

    func get_l1_address() -> (address : felt):
    end
end

# construction guard
@storage_var
func initialized() -> (res : felt):
end

# l1 gateway address
@storage_var
func l1_gateway() -> (res : felt):
end

# keep track of deposit messages, before minting
@storage_var
func mint_credits(l1_token_address : felt, amount : felt, owner : felt, l2_token_address : felt) -> (res : felt):
end

@view
func get_mint_credit{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _l1_token_address : felt, _amount : felt, _owner : felt, _l2_token_address : felt) -> (res : felt):
    let (res) = mint_credits.read(
        l1_token_address=_l1_token_address, amount=_amount, owner=_owner, l2_token_address=_l2_token_address)
    return (res)
end

# constructor
@external
func initialize{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _l1_gateway : felt):
    let (is_initialized) = initialized.read()
    assert is_initialized = 0

    l1_gateway.write(_l1_gateway)

    initialized.write(1)
    return ()
end

# receive and handle deposit messages
@l1_handler
func bridge_from_mainnet{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        from_address : felt, _owner : felt, _l1_token_address : felt, _l2_token_address : felt,
        _amount : felt):
    let (res) = l1_gateway.read()
    assert from_address = res

    let (currentNum) = mint_credits.read(
        l1_token_address=_l1_token_address,
        amount=_amount,
        owner=_owner,
        l2_token_address=_l2_token_address
    )

    mint_credits.write(
        l1_token_address=_l1_token_address,
        amount=_amount,
        owner=_owner,
        l2_token_address=_l2_token_address,
        value=currentNum + 1
    )

    return ()
end

# tries to consume mint credit
@external
func consume_mint_credit{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _l1_token_address : felt, _l2_token_address : felt, _amount : felt, _l2_owner):
    let (currentNum) = mint_credits.read(
        l1_token_address=_l1_token_address, amount=_amount, owner=_l2_owner, l2_token_address=_l2_token_address)

    assert_not_zero(currentNum)

    let (l1_token_address) = IBridgedERC20.get_l1_address(contract_address=_l2_token_address)

    assert l1_token_address = _l1_token_address

    IBridgedERC20.create_token(
        contract_address=_l2_token_address, owner=_l2_owner, amount=_amount)
    mint_credits.write(
        l1_token_address=_l1_token_address, amount=_amount, owner=_l2_owner, l2_token_address=_l2_token_address, value=currentNum - 1)

    return ()
end

# revoke mint credit if consuming is failing
@external
func revoke_mint_credit{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _l1_token_address : felt, _l2_token_address : felt, _amount : felt):
    let (caller_address) = get_caller_address()
    let (currentNum) = mint_credits.read(
        l1_token_address=_l1_token_address, amount=_amount, owner=caller_address, l2_token_address=_l2_token_address)

    assert_not_zero(currentNum)

    let (l1_gateway_address) = l1_gateway.read()

    let (message_payload : felt*) = alloc()
    assert message_payload[0] = BRIDGE_MODE_WITHDRAW
    assert message_payload[1] = caller_address
    assert message_payload[2] = _l1_token_address
    assert message_payload[3] = _l2_token_address
    assert message_payload[4] = _amount

    send_message_to_l1(to_address=l1_gateway_address, payload_size=5, payload=message_payload)

    mint_credits.write(
        l1_token_address=_l1_token_address, amount=_amount, owner=caller_address, l2_token_address=_l2_token_address, value=currentNum - 1)

    return ()
end

# burns the L2 ERC20 and sends withdrawal message
@external
func bridge_to_mainnet{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _l2_token_address : felt, _l1_token_address : felt, _amount : felt, _l1_owner : felt):
    let (caller_address) = get_caller_address()

    let (l1_token_address) = IBridgedERC20.get_l1_address(contract_address=_l2_token_address)

    assert l1_token_address = _l1_token_address

    let (l1_gateway_address) = l1_gateway.read()    

    IBridgedERC20.delete_token(contract_address=_l2_token_address, owner=caller_address, amount=_amount)

    let (message_payload : felt*) = alloc()
    assert message_payload[0] = BRIDGE_MODE_WITHDRAW
    assert message_payload[1] = _l1_owner
    assert message_payload[2] = _l1_token_address
    assert message_payload[3] = _l2_token_address
    assert message_payload[4] = _amount

    send_message_to_l1(to_address=l1_gateway_address, payload_size=5, payload=message_payload)

    return ()
end
