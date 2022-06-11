/**
 * opener-for-asana module.
 *
 * Searches for and opens an Asana task in the Chrome Omnibox
 */

import { platform } from './platform.js';

export const logSuccess = (result: string | object): void => {
  const logger = platform().logger();
  logger.log('Acted:', result);
};

export type Suggestion = {
  url: string
  text: string;
  description: string;
}

export const pullSuggestions = async (text: string): Promise<Suggestion[]> => {
  const url = `opener-for-asana:${encodeURIComponent(text)}`;
  const description = `Do some random action on "${text}"`;
  return [
    {
      url,
      text,
      description,
    },
  ];
};

export const actOnInputData = async (text: string) => {
  let parsedText = text;
  if (text.startsWith('opener-for-asana:')) {
    const url = new URL(text);
    parsedText = decodeURIComponent(url.pathname);
  }
  console.log(`Acting upon ${parsedText}`);
  return 'a success message or status';
};
