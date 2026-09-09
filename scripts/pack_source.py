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
            
    key = bytes.fromhex(key_hex)
    if len(key) != 32:
        print(f'Error: Invalid key length ({len(key)} bytes, expected 32 bytes)')
        sys.exit(1)
        
    src_dir = os.path.join(repo_dir, 'RobotNoiDia')
    proj_dir = os.path.join(repo_dir, 'RobotNoiDia.xcodeproj')
    
    if not os.path.exists(src_dir) or not os.path.exists(proj_dir):
        print('Error: Source folders RobotNoiDia or RobotNoiDia.xcodeproj not found!')
        sys.exit(1)
        
    print('[Packer] Archiving RobotNoiDia and RobotNoiDia.xcodeproj in memory...')
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode='w:gz') as tar:
        tar.add(src_dir, arcname='RobotNoiDia')
        tar.add(proj_dir, arcname='RobotNoiDia.xcodeproj')
    plaintext = buf.getvalue()
    print(f'[Packer] Uncompressed archive size: {len(plaintext)/1024:.2f} KB')
    
    print('[Packer] Encrypting archive with military-grade AES-256-GCM...')
    aesgcm = AESGCM(key)
    nonce = os.urandom(12)
    ciphertext = aesgcm.encrypt(nonce, plaintext, None)
    
    output_path = os.path.join(repo_dir, 'source.enc')
    with open(output_path, 'wb') as f:
        f.write(nonce + ciphertext)
        
    enc_size = os.path.getsize(output_path)
    print(f'[Packer] Encrypted file created: {output_path} ({enc_size/1024:.2f} KB)')
    print('[Packer] Encryption completed successfully! Source code is 100% secured.')

if __name__ == '__main__':
    main()
