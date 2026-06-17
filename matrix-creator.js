// matrix-creator.js
// 用法: node matrix-creator.js <cookie_file.json> <repo_url> <count>
// 範例: node matrix-creator.js cookies_acc1.json "https://github.com/cmwang2021/matrix-100-seed" 10

const { chromium } = require('playwright');
const fs = require('fs');

async function main() {
  const args = process.argv.slice(2);
  if (args.length < 3) {
    console.error("用法: node matrix-creator.js <cookie.json> <repo_url> <count>");
    process.exit(1);
  }

  const [cookieFile, repoUrl, countStr] = args;
  const count = parseInt(countStr, 10);
  const importUrl = `https://studio.firebase.google.com/import?url=${encodeURIComponent(repoUrl)}`;

  console.log(`[Matrix] 準備為帳號建立 ${count} 個節點...`);

  // 1. 載入 Cookies (請事先用 EditThisCookie 等套件匯出 Google 登入狀態)
  let cookies;
  try {
    cookies = JSON.parse(fs.readFileSync(cookieFile, 'utf8'));
  } catch (err) {
    console.error(`❌ 無法讀取 Cookie 檔案: ${err.message}`);
    process.exit(1);
  }

  // 2. 啟動瀏覽器
  const browser = await chromium.launch({ headless: false }); // 建議先設為 false 看它跑，穩定後改 true
  const context = await browser.newContext();
  await context.addCookies(cookies);

  const results = [];

  // 3. 循環建立
  for (let i = 1; i <= count; i++) {
    const nodeName = `pain-node-${Date.now().toString().slice(-4)}-${i}`;
    console.log(`\n[Node ${i}/${count}] 正在建立: ${nodeName}`);

    const page = await context.newPage();

    try {
      await page.goto(importUrl, { waitUntil: 'networkidle' });

      // 注意：以下的 selector 可能會隨著 Firebase Studio 的 UI 改版而需要微調
      // 這裡假設是預設的 Import 流程

      // 等待 Import 按鈕出現並點擊 (可能需要勾選同意條款)
      console.log(`  - 等待頁面載入與授權...`);

      // 如果有條款框，嘗試勾選 (這需要視實際 UI 而定)
      const checkbox = await page.$('input[type="checkbox"]');
      if (checkbox) {
          await checkbox.check();
          console.log(`  - 已勾選同意條款`);
      }

      // 點擊 Import 按鈕 (尋找包含 Import 或 匯入 字眼的按鈕)
      const importBtn = await page.waitForSelector('button:has-text("Import"), button:has-text("匯入")');
      await importBtn.click();
      console.log(`  - 點擊 Import，等待環境部署 (這可能需要 2-3 分鐘)...`);

      // 等待進入真正的 Workspace 頁面
      // Firebase Studio 建立完成後，URL 會變成 https://studio.firebase.google.com/專案Slug
      await page.waitForURL(/^https:\/\/studio\.firebase\.google\.com\/[^/]+$/, { timeout: 180000 });

      const finalUrl = page.url();
      const workspaceSlug = finalUrl.split('/').pop();

      console.log(`  ✅ 建立成功！Workspace Slug: ${workspaceSlug}`);
      console.log(`  - 喚醒網址: ${finalUrl}`);

      results.push({
        nodeName: nodeName,
        workspaceSlug: workspaceSlug,
        wakeupUrl: finalUrl,
        createdAt: new Date().toISOString()
      });

    } catch (err) {
      console.error(`  ❌ 建立失敗: ${err.message}`);
      // 可以考慮在這裡截圖
      await page.screenshot({ path: `error-${nodeName}.png` });
    } finally {
      await page.close();
    }
  }

  // 4. 儲存結果
  const outFile = `matrix-results-${Date.now()}.json`;
  fs.writeFileSync(outFile, JSON.stringify(results, null, 2));
  console.log(`\n🎉 任務完成！結果已儲存至 ${outFile}`);

  await browser.close();
}

main();
