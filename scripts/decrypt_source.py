import os
import sys
import io
import tarfile
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

def main():
    repo_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    secret_path = os.path.join(repo_dir, '.secret_key')
    
    key_hex = os.environ.get('SOURCE_ENCRYPTION_KEY')
    if not key_hex:
        if os.path.exists(secret_path):
            with open(secret_path, 'r', encoding='utf-8') as f:
                key_hex = f.read().strip()
        else:
            print('Error: SOURCE_ENCRYPTION_KEY environment variable or .secret_key file not found!')
            sys.exit(1)
            
    key = bytes.fromhex(key_hex.strip())
    if len(key) != 32:
        print(f'Error: Invalid key length ({len(key)} bytes, expected 32 bytes)')
        sys.exit(1)
        
    enc_path = os.path.join(repo_dir, 'source.enc')
    if not os.path.exists(enc_path):
        print(f'Error: {enc_path} not found!')
        sys.exit(1)
        
    print(f'[Decryptor] Reading encrypted file: {enc_path}...')
    with open(enc_path, 'rb') as f:
        data = f.read()
        
    if len(data) < 28:
        print('Error: Encrypted payload too small!')
        sys.exit(1)
        
    nonce = data[:12]
    ciphertext = data[12:]
    
    print('[Decryptor] Decrypting AES-256-GCM payload with repository secret...')
    aesgcm = AESGCM(key)
    try:
        decrypted = aesgcm.decrypt(nonce, ciphertext, None)
    except Exception as e:
        print(f'Error: Decryption failed (Authentication tag mismatch or wrong key): {e}')
        sys.exit(1)
        
    print('[Decryptor] Decryption successful! Extracting Xcode project and Swift files...')
    with tarfile.open(fileobj=io.BytesIO(decrypted), mode='r:gz') as tar:
        tar.extractall(repo_dir)
        
    print('[Decryptor] Extraction complete! Ready for compilation.')

if __name__ == '__main__':
    main()
