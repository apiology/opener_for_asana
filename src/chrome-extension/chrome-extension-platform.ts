import { ChromeExtensionCache } from './chrome-extension-cache.js';
import { ChromeExtensionConfig } from './chrome-extension-config.js';
import { ChromeExtensionLogger } from './chrome-extension-logger.js';
import { ChromeExtensionFormatter } from './chrome-extension-formatter.js';
import { ChromeExtensionBrowser } from './chrome-extension-browser.js';

export class ChromeExtensionPlatform {
  config = () => new ChromeExtensionConfig();

  cache = () => new ChromeExtensionCache();

  logger = () => new ChromeExtensionLogger();

  formatter = () => new ChromeExtensionFormatter();

  browser = () => new ChromeExtensionBrowser();
}
