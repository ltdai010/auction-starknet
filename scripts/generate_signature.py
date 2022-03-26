from starkware.crypto.signature.signature import (
    pedersen_hash, private_to_stark_key, sign)
from starkware.cairo.common.hash_state import compute_hash_on_elements

def hash_message(sender, to, selector, calldata, nonce):
    message = [sender, to, selector, compute_hash_on_elements(calldata), nonce]
    return compute_hash_on_elements(message)


private_key = 185966504860111059458722037768194983456
message_hash = hash_message(970925682883204735824614266055324980230346129656691612724475122793121360836,
    523365991586998650869876321885921144119977304655117497737574868191962598989,
    949021990203918389843157787496164629863144228991510976554585288817234167820,
    [1890196054054660974515131945497179926644328784963156654015561433662482338284,
    1],
    1)
# message_hash = pedersen_hash(4321)
signature = sign(msg_hash=message_hash, priv_key=private_key)
public_key = private_to_stark_key(private_key)
print(f'hash: {message_hash}')
print(f'Public key: {public_key}')
print(f'Signature: {signature}')

