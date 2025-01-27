import { Cache } from './cache.js';
import { Config } from './config.js';
import { Logger } from './logger.js';
import { Formatter } from './formatter.js';
import { Browser } from './browser.js';

interface Platform {
  config(): Config;

  cache(): Cache;

  logger(): Logger;

  formatter(): Formatter;

  browser(): Browser;
}

let thePlatform: Platform | null = null;

export const platform = (): Platform => {
  if (thePlatform == null) {
    throw Error('Please call setPlatform() before use');
  }
  return thePlatform;
};

export const setPlatform = (newPlatform: Platform) => {
  thePlatform = newPlatform;
};
