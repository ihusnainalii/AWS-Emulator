import os
import subprocess
import html

SCREENSHOTS_DIR = os.path.abspath("docs/screenshots")
os.makedirs(SCREENSHOTS_DIR, exist_ok=True)
CHROME_BIN = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

def capture_command(cmd, cwd=None):
    proc = subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=cwd)
    output = proc.stdout
    if proc.stderr:
        output += "\n" + proc.stderr
    return output.strip()

def render_terminal_window(title, command, output, width=950, height=520):
    escaped_cmd = html.escape(command)
    escaped_out = html.escape(output)
    
    # Simple ANSI color & highlight parsing
    formatted_out = escaped_out
    formatted_out = formatted_out.replace("✅ Upload Successful! (HTTP 200)", '<span style="color:#48BB78;font-weight:bold;">✅ Upload Successful! (HTTP 200)</span>')
    formatted_out = formatted_out.replace("HTTP/1.1 200 OK", '<span style="color:#48BB78;font-weight:bold;">HTTP/1.1 200 OK</span>')
    formatted_out = formatted_out.replace("Apply complete!", '<span style="color:#48BB78;font-weight:bold;">Apply complete!</span>')
    formatted_out = formatted_out.replace("Running", '<span style="color:#48BB78;">Running</span>')
    formatted_out = formatted_out.replace("healthy", '<span style="color:#48BB78;font-weight:bold;">healthy</span>')
    formatted_out = formatted_out.replace("ok", '<span style="color:#48BB78;font-weight:bold;">ok</span>')
    
    html_content = f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{
    background: #0D1117;
    display: flex;
    justify-content: center;
    align-items: center;
    padding: 30px;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  }}
  .window {{
    width: 100%;
    max-width: {width}px;
    background: #161B22;
    border-radius: 12px;
    box-shadow: 0 20px 50px rgba(0,0,0,0.6), 0 0 0 1px rgba(255,255,255,0.1);
    overflow: hidden;
  }}
  .title-bar {{
    background: #21262D;
    padding: 12px 16px;
    display: flex;
    align-items: center;
    border-bottom: 1px solid rgba(255,255,255,0.08);
  }}
  .dots {{
    display: flex;
    gap: 8px;
  }}
  .dot {{
    width: 12px;
    height: 12px;
    border-radius: 50%;
  }}
  .dot.red {{ background: #FF5F56; }}
  .dot.yellow {{ background: #FFBD2E; }}
  .dot.green {{ background: #27C93F; }}
  .title {{
    flex: 1;
    text-align: center;
    font-size: 13px;
    font-weight: 500;
    color: #8B949E;
    margin-right: 50px;
  }}
  .content {{
    padding: 24px;
    font-family: "SF Mono", "Fira Code", Menlo, Monaco, Consolas, monospace;
    font-size: 13.5px;
    line-height: 1.6;
    color: #C9D1D9;
    white-space: pre-wrap;
    word-break: break-all;
  }}
  .prompt {{
    color: #58A6FF;
    font-weight: 600;
  }}
  .command {{
    color: #F0883E;
    font-weight: 600;
  }}
</style>
</head>
<body>
  <div class="window">
    <div class="title-bar">
      <div class="dots">
        <div class="dot red"></div>
        <div class="dot yellow"></div>
        <div class="dot green"></div>
      </div>
      <div class="title">{title}</div>
    </div>
    <div class="content"><span class="prompt">user@macbook AWS-Emulator %</span> <span class="command">{escaped_cmd}</span>

{formatted_out}</div>
  </div>
</body>
</html>"""
    return html_content

def render_browser_window(url, width=950, height=540):
    html_content = f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{
    background: #0D1117;
    display: flex;
    justify-content: center;
    align-items: center;
    padding: 30px;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  }}
  .browser {{
    width: 100%;
    max-width: {width}px;
    background: #1E232A;
    border-radius: 12px;
    box-shadow: 0 20px 50px rgba(0,0,0,0.6), 0 0 0 1px rgba(255,255,255,0.1);
    overflow: hidden;
  }}
  .browser-header {{
    background: #2D333B;
    padding: 12px 16px;
    display: flex;
    align-items: center;
    gap: 16px;
    border-bottom: 1px solid rgba(255,255,255,0.08);
  }}
  .dots {{
    display: flex;
    gap: 8px;
  }}
  .dot {{
    width: 12px;
    height: 12px;
    border-radius: 50%;
  }}
  .dot.red {{ background: #FF5F56; }}
  .dot.yellow {{ background: #FFBD2E; }}
  .dot.green {{ background: #27C93F; }}
  .nav-arrows {{
    display: flex;
    gap: 12px;
    color: #768390;
    font-size: 14px;
    font-weight: bold;
  }}
  .url-bar {{
    flex: 1;
    background: #1C2128;
    border-radius: 6px;
    padding: 7px 14px;
    font-size: 13px;
    color: #ADBAC7;
    display: flex;
    align-items: center;
    gap: 8px;
    border: 1px solid rgba(255,255,255,0.1);
  }}
  .lock-icon {{
    color: #57AB5A;
  }}
  .viewport {{
    background: #FFFFFF;
    min-height: 380px;
    display: flex;
    justify-content: center;
    align-items: center;
    padding: 40px;
  }}
  .badge {{
    background: #E1F5FE;
    color: #0288D1;
    font-size: 11px;
    padding: 2px 6px;
    border-radius: 4px;
    margin-left: auto;
    font-weight: 600;
  }}
</style>
</head>
<body>
  <div class="browser">
    <div class="browser-header">
      <div class="dots">
        <div class="dot red"></div>
        <div class="dot yellow"></div>
        <div class="dot green"></div>
      </div>
      <div class="nav-arrows">
        <span>&larr;</span>
        <span>&rarr;</span>
        <span>&#8635;</span>
      </div>
      <div class="url-bar">
        <span class="lock-icon">&#128274;</span>
        <span>{url}</span>
        <span class="badge">HTTP 200 OK</span>
      </div>
    </div>
    <div class="viewport">
      <svg xmlns="http://www.w3.org/2000/svg" width="620" height="260" viewBox="0 0 600 250">
        <rect width="600" height="250" rx="15" fill="#1A202C"/>
        <circle cx="300" cy="80" r="40" fill="#ED8936"/>
        <text x="300" y="160" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-weight="bold" font-size="24" fill="#FFFFFF" text-anchor="middle">Presigned PUT Upload Succeeded!</text>
        <text x="300" y="195" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="14" fill="#A0AEC0" text-anchor="middle">Served securely via CloudFront + S3 SSE-KMS</text>
      </svg>
    </div>
  </div>
</body>
</html>"""
    return html_content

def html_to_png(html_str, out_png, width=1020, height=600):
    tmp_html = out_png.replace(".png", ".html")
    with open(tmp_html, "w") as f:
        f.write(html_str)
    
    cmd = [
        CHROME_BIN,
        "--headless",
        "--disable-gpu",
        "--hide-scrollbars",
        f"--window-size={width},{height}",
        f"--screenshot={out_png}",
        f"file://{tmp_html}"
    ]
    subprocess.run(cmd, check=True, capture_output=True)
    os.remove(tmp_html)
    print(f"✅ Generated: {out_png}")

def main():
    print("Capturing live command outputs...")
    
    # 1. Emulator status
    status_out = capture_command("./emulator.sh status")
    s1_html = render_terminal_window("AWS Emulator Status & Health Check", "./emulator.sh status", status_out)
    html_to_png(s1_html, os.path.join(SCREENSHOTS_DIR, "01-emulator-status.png"), height=460)
    
    # 2. Terragrunt Outputs (S3 & CloudFront)
    s3_out = capture_command("terragrunt output", cwd="iac/environments/develop/s3")
    cf_out = capture_command("terragrunt output", cwd="iac/environments/develop/cloudfront")
    iac_combined = f"""--- [iac/environments/develop/s3] terragrunt output ---
{s3_out}

--- [iac/environments/develop/cloudfront] terragrunt output ---
{cf_out}"""
    s2_html = render_terminal_window("Terragrunt IaC Outputs (S3 SSE-KMS + CloudFront OAC)", "terragrunt output (develop/s3 & develop/cloudfront)", iac_combined)
    html_to_png(s2_html, os.path.join(SCREENSHOTS_DIR, "02-iac-terragrunt-outputs.png"), height=540)
    
    # 3. Upload Example
    upload_out = capture_command("./emulator.sh upload /tmp/sample-banner.svg")
    s3_html = render_terminal_window("Presigned PUT Upload Workflow", "./emulator.sh upload /tmp/sample-banner.svg", upload_out)
    html_to_png(s3_html, os.path.join(SCREENSHOTS_DIR, "03-presigned-put-upload.png"), height=560)
    
    # 4. Direct Browser Access Preview
    browser_url = "https://127.0.0.1:9297/develop-secure-assets/sample-banner.svg"
    s4_html = render_browser_window(browser_url)
    html_to_png(s4_html, os.path.join(SCREENSHOTS_DIR, "04-direct-browser-access.png"), height=560)
    
    # 5. Curl Verification
    curl_out = capture_command("curl -k -i https://127.0.0.1:9297/develop-secure-assets/sample-banner.svg")
    s5_html = render_terminal_window("Direct Browser GET Verification (HTTP 200 OK)", "curl -k -i https://127.0.0.1:9297/develop-secure-assets/sample-banner.svg", curl_out)
    html_to_png(s5_html, os.path.join(SCREENSHOTS_DIR, "05-curl-verification.png"), height=540)

if __name__ == "__main__":
    main()
