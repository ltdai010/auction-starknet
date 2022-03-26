%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt, uint256_check
)

# ========= Struct ========= #

struct Auction:
    member start_price: felt
    member highest_bidder: felt
    member coin_buy: felt
    member creator: felt
    member ended: felt
end

# ========= Struct ========= #

# ========= Var ========= #

const EMPTY_ADDRESS = 0

# ========= Var ========= #

# ========= Storage ========= #

@storage_var
func map_auction(contract_sale: felt, token_id: felt) -> (auction: Auction):
end

@storage_var
func map_bidder(contract_sale: felt, token_id: felt, bidder: felt) -> (bidded_balance: Uint256):
end

# ========= Storage ========= #

# ========= Interface ========= #
@contract_interface
namespace IERC721:
    func balance_of(owner: felt) -> (res: felt):
    end

    func owner_of(token_id: felt) -> (res: felt):
    end

    func approve(to: felt, token_id: felt):
    end

    func get_approved(token_id: felt) -> (res: felt):
    end

    func transfer_from(_from: felt, to: felt, token_id: felt):
    end
end

@contract_interface
namespace IERC20:
    func name() -> (name: felt):
    end

    func symbol() -> (symbol: felt):
    end

    func decimals() -> (decimals: felt):
    end

    func totalSupply() -> (totalSupply: Uint256):
    end

    func balanceOf(account: felt) -> (balance: Uint256):
    end

    func allowance(owner: felt, spender: felt) -> (remaining: Uint256):
    end

    func transfer(recipient: felt, amount: Uint256) -> (success: felt):
    end

    func transferFrom(
            sender: felt, 
            recipient: felt, 
            amount: Uint256
        ) -> (success: felt):
    end

    func approve(spender: felt, amount: Uint256) -> (success: felt):
    end
end

# ========= Interface ========= #

# ========= Getter ========= #

@view
func auction_info{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    _contract_sale: felt, _token_id: felt) -> (res: Auction):
    let (auction) = map_auction.read(contract_sale=_contract_sale, token_id=_token_id)
    return (auction)
end

@view
func bidded_balance{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    _contract_sale: felt, _token_id: felt, _bidder: felt) -> (res: Uint256):
    let (bidded) = map_bidder.read(contract_sale=_contract_sale, token_id=_token_id, bidder=_bidder)
    return (bidded)
end


# ========= Getter ========= #

# ========= Setter ========= #

@external
func start{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    _contract_sale: felt, _token_id: felt, _coin_buy: felt, _start_price: felt):
    let (owner_address) = IERC721.owner_of(contract_address=_contract_sale, token_id=_token_id)
    let (caller) = get_caller_address()

    assert owner_address = caller
    let (this_address) = get_contract_address()
    IERC721.transfer_from(contract_address=_contract_sale, _from=owner_address, to=this_address, token_id=_token_id)
    let auction = Auction(
        start_price=_start_price,
        highest_bidder=EMPTY_ADDRESS,
        coin_buy=_coin_buy,
        creator=caller,
        ended=0
    )
    map_auction.write(contract_sale=_contract_sale, token_id=_token_id, value=auction)
    return ()
end

@external
func bid{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    _contract_sale: felt, _token_id: felt, amount: Uint256):
    alloc_locals
    let (auction) = map_auction.read(contract_sale=_contract_sale, token_id=_token_id)
    assert_not_zero(auction.creator)
    let (local caller) = get_caller_address()
    let (this_address) = get_contract_address()
    
    # transfer to sale contract
    let (bid) = map_bidder.read(contract_sale=_contract_sale, token_id=_token_id, bidder=caller)
    IERC20.transferFrom(contract_address=auction.coin_buy, sender=caller, recipient=this_address, amount=amount)
    let (highest_bid) = map_bidder.read(contract_sale=_contract_sale, token_id=_token_id, bidder=auction.highest_bidder)
    # add old bid with new bid
    let (new_bid, _: Uint256) = uint256_add(bid, amount)
    # compare highest bid with new bid
    let (higher) = uint256_lt(highest_bid, new_bid)
    assert_not_zero(higher)
    # update map bidder
    map_bidder.write(contract_sale=_contract_sale, token_id=_token_id, bidder=caller, value=new_bid)
    return ()
end

@external
func withdraw{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    _contract_sale: felt, _token_id: felt):
    let (auction) = map_auction.read(contract_sale=_contract_sale, token_id=_token_id)
    assert auction.ended = 1
    let (caller) = get_caller_address()
    let (this_address) = get_contract_address()
    let (bidded) = map_bidder.read(contract_sale=_contract_sale, token_id=_token_id, bidder=caller)

    IERC20.transferFrom(contract_address=auction.coin_buy, sender=this_address, recipient=caller, amount=bidded)
    map_bidder.write(contract_sale=_contract_sale, token_id=_token_id, bidder=caller, value=Uint256(0,0))
    return ()
end

@external
func finish{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    _contract_sale: felt, _token_id: felt):
    alloc_locals
    let (local auction) = map_auction.read(contract_sale=_contract_sale, token_id=_token_id)
    let (local caller) = get_caller_address()
    let (local this_address) = get_contract_address()
    assert auction.ended = 0
    assert auction.creator = caller
    if auction.highest_bidder == 0:
        IERC721.transfer_from(contract_address=_contract_sale, _from=this_address, to=auction.creator, token_id=_token_id)
        tempvar syscall_ptr :felt* = syscall_ptr
        tempvar pedersen_ptr : HashBuiltin* = pedersen_ptr
    else:
        # transfer erc721 to highest bidder
        IERC721.transfer_from(contract_address=_contract_sale, _from=this_address, to=auction.highest_bidder, token_id=_token_id)
        tempvar syscall_ptr :felt* = syscall_ptr
        tempvar pedersen_ptr : HashBuiltin* = pedersen_ptr
        let (local bidded) = map_bidder.read(contract_sale=_contract_sale, token_id=_token_id, bidder=caller)
        # transfer coins to creator
        IERC20.transferFrom(contract_address=auction.coin_buy, sender=this_address, recipient=auction.creator, amount=bidded)
        tempvar syscall_ptr :felt* = syscall_ptr
        tempvar pedersen_ptr : HashBuiltin* = pedersen_ptr
        # set balance to 0
        map_bidder.write(contract_sale=_contract_sale, token_id=_token_id, bidder=auction.highest_bidder, value=Uint256(0,0))
        tempvar syscall_ptr :felt* = syscall_ptr
        tempvar pedersen_ptr : HashBuiltin* = pedersen_ptr
    end
    auction.ended = 1
    map_auction.write(contract_sale=_contract_sale, token_id=_token_id, value=auction)
    return ()
end



# ========= Setter ========= #
