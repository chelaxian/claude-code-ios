// Polyfill for broken Intl.Segmenter on iOS
// V8's ICU break iterator data is incomplete, causing crashes
// This provides a JavaScript-based replacement

class SegmenterShim {
  constructor(locale = 'en', options = {}) {
    this.locale = locale;
    this.granularity = options.granularity || 'grapheme';
  }

  segment(str) {
    const granularity = this.granularity;
    let segments = [];

    if (granularity === 'word') {
      // Word segmentation using regex
      const matches = str.matchAll(/(\s+)|(\S+)/g);
      for (const match of matches) {
        segments.push({
          segment: match[0],
          index: match.index,
          isWordLike: !/^\s+$/.test(match[0])
        });
      }
    } else if (granularity === 'sentence') {
      // Sentence segmentation
      const matches = str.matchAll(/[^.!?]*[.!?]+\s*/g);
      let lastIndex = 0;
      for (const match of matches) {
        segments.push({
          segment: match[0],
          index: match.index,
          isWordLike: true
        });
        lastIndex = match.index + match[0].length;
      }
      // Handle remaining text without punctuation
      if (lastIndex < str.length) {
        segments.push({
          segment: str.slice(lastIndex),
          index: lastIndex,
          isWordLike: true
        });
      }
    } else {
      // Grapheme segmentation (character by character)
      // Note: This doesn't handle complex grapheme clusters perfectly
      for (let i = 0; i < str.length; i++) {
        segments.push({
          segment: str[i],
          index: i,
          isWordLike: !/\s/.test(str[i])
        });
      }
    }

    const result = {
      [Symbol.iterator]: function* () {
        for (const seg of segments) yield seg;
      },
      containing(index) {
        return segments.find(s => s.index <= index && index < s.index + s.segment.length);
      }
    };

    return result;
  }

  resolvedOptions() {
    return {
      locale: this.locale,
      granularity: this.granularity
    };
  }

  static supportedLocalesOf(locales) {
    // Claim to support all locales since we're using basic regex
    return Array.isArray(locales) ? locales : [locales];
  }
}

// Replace the broken native Segmenter
Intl.Segmenter = SegmenterShim;
