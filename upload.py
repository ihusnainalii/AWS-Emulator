#!/usr/bin/env python3

import os
import sys
import datetime
import hmac
import hashlib
import mimetypes
import urllib.parse
import urllib.request
import ssl
import xml.etree.ElementTree as ET

def sign(key, msg):
    return hmac.new(key, msg.encode("utf-8"), hashlib.sha256).digest()

def get_signature_key(key, date_stamp, region_name, service_name):
    k_date = sign(("AWS4" + key).encode("utf-8"), date_stamp)
    k_region = sign(k_date, region_name)
    k_service = sign(k_region, service_name)
    k_signing = sign(k_service, "aws4_request")
    return k_signing

def get_emulator_credentials(port="9297"):
    cred_path = os.path.expanduser(f"~/.aws/emulator/{port}/emulator_credentials")
    if os.path.exists(cred_path):
        access_key, secret_key = None, None
        with open(cred_path) as f:
            for line in f:
                if line.startswith("aws_access_key_id"):
                    access_key = line.split("=")[1].strip()
                elif line.startswith("aws_secret_access_key"):
                    secret_key = line.split("=")[1].strip()
        if access_key and secret_key:
            return access_key, secret_key
        
    return "mock_access_key", "mock_secret_key"

def generate_presigned_url(http_method, bucket, key, access_key, secret_key, host="127.0.0.1:9297", region="us-east-1", expires_in=3600):
    service = "s3"
    now = datetime.datetime.now(datetime.timezone.utc)
    amz_date = now.strftime("%Y%m%dT%H%M%SZ")
    date_stamp = now.strftime("%Y%m%d")

    credential_scope = f"{date_stamp}/{region}/{service}/aws4_request"
    canonical_uri = f"/{bucket}/{key.lstrip('/')}"
    cred_param = urllib.parse.quote_plus(f"{access_key}/{credential_scope}")

    canonical_querystring = (
        f"X-Amz-Algorithm=AWS4-HMAC-SHA256"
        f"&X-Amz-Credential={cred_param}"
        f"&X-Amz-Date={amz_date}"
        f"&X-Amz-Expires={expires_in}"
        f"&X-Amz-SignedHeaders=host"
    )

    canonical_headers = f"host:{host}\n"
    signed_headers = "host"
    payload_hash = "UNSIGNED-PAYLOAD"

    canonical_request = f"{http_method.upper()}\n{canonical_uri}\n{canonical_querystring}\n{canonical_headers}\n{signed_headers}\n{payload_hash}"
    string_to_sign = f"AWS4-HMAC-SHA256\n{amz_date}\n{credential_scope}\n{hashlib.sha256(canonical_request.encode()).hexdigest()}"

    signing_key = get_signature_key(secret_key, date_stamp, region, service)
    signature = hmac.new(signing_key, string_to_sign.encode(), hashlib.sha256).hexdigest()

    return f"https://{host}{canonical_uri}?{canonical_querystring}&X-Amz-Signature={signature}"

def cleanup_old_versions_if_needed(bucket, key, file_size, host="127.0.0.1:9297"):
    """If file is large (>15MB), clean up older versions of this key in emulator to prevent hitting 64MB bucket limit."""
    if file_size <= 15 * 1024 * 1024:
        return
    
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    
    try:
        url = f"https://{host}/{bucket}?versions&prefix={urllib.parse.quote(key)}"
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, context=ctx) as resp:
            root = ET.fromstring(resp.read().decode())
            for ver in root.findall(".//{*}Version"):
                v_key = ver.find("{*}Key").text
                v_id = ver.find("{*}VersionId").text
                if v_key == key:
                    del_url = f"https://{host}/{bucket}/{key}?versionId={v_id}"
                    del_req = urllib.request.Request(del_url, method="DELETE")
                    try:
                        with urllib.request.urlopen(del_req, context=ctx):
                            pass
                    except Exception:
                        pass
    except Exception:
        pass

def upload_multipart(local_file, bucket, s3_target_path, content_type, host="127.0.0.1:9297"):
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    file_size = os.path.getsize(local_file)
    part_size = 8 * 1024 * 1024  # 8 MB per part
    num_parts = (file_size + part_size - 1) // part_size

    print(f"-> File size ({file_size} bytes, {file_size / (1024*1024):.1f} MB) exceeds single PUT limit (16 MB).")
    print(f"-> Utilizing S3 Multipart Upload with {num_parts} parts (8 MB chunks)...")

    cleanup_old_versions_if_needed(bucket, s3_target_path, file_size, host)
    upload_id = None

    try:
        # 1. Initiate Multipart Upload
        init_url = f"https://{host}/{bucket}/{s3_target_path}?uploads"
        init_req = urllib.request.Request(
            init_url,
            headers={"Content-Type": content_type},
            method="POST"
        )
        with urllib.request.urlopen(init_req, context=ctx) as resp:
            root = ET.fromstring(resp.read().decode())
            upload_id = root.find(".//{*}UploadId").text

        print(f"   Upload ID: {upload_id}")

        # 2. Upload Parts
        parts = []
        with open(local_file, "rb") as f:
            for part_num in range(1, num_parts + 1):
                chunk = f.read(part_size)
                print(f"   Uploading part {part_num}/{num_parts} ({len(chunk)} bytes)...", end="", flush=True)
                part_url = f"https://{host}/{bucket}/{s3_target_path}?partNumber={part_num}&uploadId={upload_id}"
                part_req = urllib.request.Request(part_url, data=chunk, method="PUT")
                with urllib.request.urlopen(part_req, context=ctx) as resp:
                    etag = resp.headers.get("ETag")
                    parts.append((part_num, etag))
                    print(f" [OK] ETag: {etag}")

        # 3. Complete Multipart Upload
        complete_url = f"https://{host}/{bucket}/{s3_target_path}?uploadId={upload_id}"
        parts_xml = "\n".join([f"  <Part><PartNumber>{p[0]}</PartNumber><ETag>{p[1]}</ETag></Part>" for p in parts])
        complete_body = f"""<CompleteMultipartUpload xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
{parts_xml}
</CompleteMultipartUpload>""".encode("utf-8")

        complete_req = urllib.request.Request(
            complete_url,
            data=complete_body,
            headers={"Content-Type": "application/xml"},
            method="POST"
        )
        with urllib.request.urlopen(complete_req, context=ctx) as resp:
            version_id = resp.headers.get("x-amz-version-id", "N/A")
            kms_key = resp.headers.get("x-amz-server-side-encryption-aws-kms-key-id", "N/A")
            print(f"✅ Multipart Upload Successful! (HTTP {resp.status})")
            print(f"   Version ID: {version_id}")
            print(f"   KMS Key:    {kms_key}")

    except urllib.error.HTTPError as e:
        err_msg = e.read().decode("utf-8", errors="replace")
        print(f"\n❌ Multipart Upload Failed: {e.code} {e.reason}", file=sys.stderr)
        
        # Abort multipart upload if active to free memory
        if upload_id:
            try:
                abort_url = f"https://{host}/{bucket}/{s3_target_path}?uploadId={upload_id}"
                abort_req = urllib.request.Request(abort_url, method="DELETE")
                with urllib.request.urlopen(abort_req, context=ctx):
                    print("   [Cleaned up incomplete multipart upload session]", file=sys.stderr)
            except Exception:
                pass
                
        # Parse XML error message
        try:
            root = ET.fromstring(err_msg)
            msg = root.find(".//Message")
            if msg is not None and msg.text:
                print(f"   Details: {msg.text}", file=sys.stderr)
            else:
                print(f"   Details: {err_msg}", file=sys.stderr)
        except Exception:
            print(f"   Details: {err_msg}", file=sys.stderr)
            
        sys.exit(1)

def main():
    if len(sys.argv) < 2:
        print("Usage: ./upload.py <local_file_path> [s3_target_path] [bucket_name]")
        print("Example: ./upload.py ./my-image.png                   # Uploads to S3 root: develop-secure-assets/my-image.png")
        print("Example: ./upload.py ./my-image.png custom/path.png # Uploads to specific S3 path")
        print("\nNo file argument provided. Creating a sample SVG image for demonstration...")
        local_file = "/tmp/sample-banner.svg"
        with open(local_file, "w") as f:
            f.write('''<svg xmlns="http://www.w3.org/2000/svg" width="600" height="250" viewBox="0 0 600 250">
  <rect width="600" height="250" rx="15" fill="#1A202C"/>
  <circle cx="300" cy="80" r="40" fill="#ED8936"/>
  <text x="300" y="160" font-family="-apple-system, sans-serif" font-weight="bold" font-size="24" fill="#FFFFFF" text-anchor="middle">Presigned PUT Upload Succeeded!</text>
  <text x="300" y="195" font-family="-apple-system, sans-serif" font-size="14" fill="#A0AEC0" text-anchor="middle">Served securely via CloudFront + S3 SSE-KMS</text>
</svg>''')
        s3_target_path = "sample-banner.svg"
        bucket = "develop-secure-assets"
    else:
        local_file = sys.argv[1]
        # When only local file path is provided, upload directly to the root of the bucket using filename
        s3_target_path = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2].strip() else os.path.basename(local_file)
        s3_target_path = s3_target_path.lstrip("/")
        bucket = sys.argv[3] if len(sys.argv) > 3 else "develop-secure-assets"

    if not os.path.exists(local_file):
        print(f"Error: Local file '{local_file}' does not exist.", file=sys.stderr)
        sys.exit(1)

    # 1. Fetch credentials from local emulator
    access_key, secret_key = get_emulator_credentials("9297")

    file_size = os.path.getsize(local_file)
    content_type, _ = mimetypes.guess_type(local_file)
    content_type = content_type or "application/octet-stream"

    if file_size > 15 * 1024 * 1024:
        # Files > 15MB use S3 Multipart Upload (single HTTP PUT is limited to 16MB)
        print("==================================================")
        print("1. MULTIPART UPLOAD (Chunked Presigned Flow)")
        print("==================================================")
        upload_multipart(local_file, bucket, s3_target_path, content_type)
    else:
        # Files <= 15MB use standard single Presigned PUT URL
        presigned_put_url = generate_presigned_url("PUT", bucket, s3_target_path, access_key, secret_key)
        print("==================================================")
        print("1. GENERATED PRESIGNED PUT URL")
        print("==================================================")
        print(presigned_put_url)
        print()

        with open(local_file, "rb") as f:
            file_bytes = f.read()

        print(f"-> Uploading '{local_file}' ({len(file_bytes)} bytes, {content_type}) to S3 path '{s3_target_path}'...")

        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

        req = urllib.request.Request(
            presigned_put_url,
            data=file_bytes,
            headers={"Content-Type": content_type},
            method="PUT"
        )

        try:
            with urllib.request.urlopen(req, context=ctx) as response:
                version_id = response.headers.get("x-amz-version-id", "N/A")
                kms_key = response.headers.get("x-amz-server-side-encryption-aws-kms-key-id", "N/A")
                print(f"✅ Upload Successful! (HTTP {response.status})")
                print(f"   Version ID: {version_id}")
                print(f"   KMS Key:    {kms_key}")
        except urllib.error.HTTPError as e:
            print(f"❌ Upload Failed: {e.code} {e.reason}", file=sys.stderr)
            print(e.read().decode("utf-8", errors="replace"), file=sys.stderr)
            sys.exit(1)

    # 4. Generate Direct Access Link
    direct_browser_url = f"https://127.0.0.1:9297/{bucket}/{s3_target_path}"

    print()
    print("==================================================")
    print("2. DIRECT ACCESS LINK (No Presigned URL Needed)")
    print("==================================================")
    print("🌐 Direct Browser Link (Click to Open):")
    print(f"   {direct_browser_url}")
    print("==================================================")

if __name__ == "__main__":
    main()
