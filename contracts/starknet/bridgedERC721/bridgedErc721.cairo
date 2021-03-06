%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_not_equal, assert_not_zero

@storage_var
func owners(token_id : felt) -> (res : felt):
end

@storage_var
func balances(owner : felt) -> (res : felt):
end

@storage_var
func token_approvals(token_id : felt) -> (res : felt):
end

@storage_var
func operator_approvals(owner : felt, operator : felt) -> (res : felt):
end

@storage_var
func l1_address() -> (res : felt):
end

@storage_var
func gateway_address() -> (res : felt):
end

@constructor
func constructor{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        _l1_address : felt, _gateway_address : felt):
    l1_address.write(_l1_address)
    gateway_address.write(_gateway_address)

    return ()
end

@view
func balance_of{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt) -> (res : felt):
    assert_not_zero(owner)

    let (res) = balances.read(owner=owner)
    return (res)
end

@view
func owner_of{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_id : felt) -> (res : felt):
    let (res) = owners.read(token_id=token_id)
    assert_not_zero(res)

    return (res)
end

func _approve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        to : felt, token_id : felt):
    token_approvals.write(token_id=token_id, value=to)
    return ()
end

@external
func approve{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        to : felt, token_id : felt):
    let (owner) = owners.read(token_id)

    assert_not_equal(owner, to)

    let (is_operator_or_owner) = _is_operator_or_owner(owner)
    assert_not_zero(is_operator_or_owner)

    _approve(to, token_id)
    return ()
end

func _is_operator_or_owner{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        address : felt) -> (res : felt):
    let (caller) = get_caller_address()

    if caller == address:
        return (1)
    end

    let (is_approved_for_all) = operator_approvals.read(owner=caller, operator=address)
    return (is_approved_for_all)
end

func _is_approved_or_owner{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        spender : felt, token_id : felt) -> (res : felt):
    alloc_locals
    let (exists) = _exists(token_id)
    assert exists = 1

    let (owner) = owner_of(token_id)
    if owner == spender:
        return (1)
    end

    let (approved_addr) = get_approved(token_id)
    if approved_addr == spender:
        return (1)
    end

    let (is_operator) = is_approved_for_all(owner, spender)
    if is_operator == 1:
        return (1)
    end

    return (0)
end

func _exists{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_id : felt) -> (res : felt):
    let (res) = owners.read(token_id)
    if res == 0:
        return (0)
    else:
        return (1)
    end
end

@view
func get_approved{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_id : felt) -> (res : felt):
    let (exists) = _exists(token_id)
    assert exists = 1

    let (res) = token_approvals.read(token_id=token_id)
    return (res)
end

@view
func is_approved_for_all{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt, operator : felt) -> (res : felt):
    let (res) = operator_approvals.read(owner=owner, operator=operator)
    return (res)
end

func _mint{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        to : felt, token_id : felt):
    assert_not_zero(to)

    let (exists) = _exists(token_id)
    assert exists = 0

    # beforeTokenTransfer

    let (balance) = balances.read(to)
    balances.write(to, balance + 1)

    owners.write(token_id, to)

    return ()
end

func _burn{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(token_id : felt):
    let (owner) = owner_of(token_id)

    # before token transfer

    # Clear approvals
    _approve(0, token_id)

    # Decrease owner balance
    let (balance) = balances.read(owner)
    balances.write(owner, balance - 1)

    # delete owner
    owners.write(token_id, 0)

    return ()
end

func _transfer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _from : felt, to : felt, token_id : felt):
    let (_owner_of) = owner_of(token_id)
    assert _owner_of = _from

    assert_not_zero(to)

    # beforeTokenTransfer

    # clear approvals from previous owner
    _approve(0, token_id)

    # Decrease owner balance
    let (owner_bal) = balances.read(_from)
    balances.write(owner=_from, value=(owner_bal - 1))

    # Increase receiver balance
    let (receiver_bal) = balances.read(to)
    balances.write(owner=to, value=(receiver_bal + 1))

    # Update token_id owner
    owners.write(token_id=token_id, value=to)

    return ()
end

func _set_approval_for_all{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt, operator : felt, approved : felt):
    assert_not_equal(owner, operator)

    # Make sure `approved` is a boolean (0 or 1)
    assert approved * (1 - approved) = 0

    operator_approvals.write(owner=owner, operator=operator, value=approved)
    return ()
end

@external
func set_approval_for_all{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        operator : felt, approved : felt):
    let (caller) = get_caller_address()

    _set_approval_for_all(caller, operator, approved)
    return ()
end

@external
func transfer_from{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        _from : felt, to : felt, token_id : felt):
    let (caller) = get_caller_address()
    _is_approved_or_owner(caller, token_id=token_id)

    _transfer(_from, to, token_id)
    return ()
end

@external
func create_token{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt, token_id : felt):
    let (caller) = get_caller_address()
    let (_gateway_address) = gateway_address.read()
    assert caller = _gateway_address

    _mint(owner, token_id)
    return ()
end

@external
func delete_token{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_id : felt):
    let (caller) = get_caller_address()
    let (_gateway_address) = gateway_address.read()
    assert caller = _gateway_address

    _burn(token_id)
    return ()
end

@view
func get_l1_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        address : felt):
    let (address) = l1_address.read()
    return (address)
end
