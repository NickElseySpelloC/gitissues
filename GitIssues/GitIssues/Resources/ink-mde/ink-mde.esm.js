import { ssr, ssrHydrationKey, escape, createComponent, ssrAttribute, ssrElement, mergeProps, renderToString as renderToString$1 } from 'solid-js/web';
import { syntaxTree, syntaxHighlighting, HighlightStyle } from '@codemirror/language';
import { SelectionRange, EditorSelection, Compartment, RangeSetBuilder, EditorState, StateField, RangeSet } from '@codemirror/state';
import { defaultKeymap, historyKeymap, history } from '@codemirror/commands';
import { EditorView, Decoration, ViewPlugin, keymap } from '@codemirror/view';
import { markdown as markdown$1, markdownLanguage } from '@codemirror/lang-markdown';
import { languages } from '@codemirror/language-data';
import { tags, Tag } from '@lezer/highlight';
import { createSignal, Show, onMount, onCleanup, For, createEffect, createContext, useContext } from 'solid-js';

const HYDRATION_MARKER = "data-ink-mde-ssr-hydration-marker";
const HYDRATION_MARKER_SELECTOR = `[${HYDRATION_MARKER}]`;
const getHydrationMarkerProps = () => {
  {
    return {
      [HYDRATION_MARKER]: true
    };
  }
};

const destroy = ([state]) => {
  const { editor } = state();
  editor.destroy();
};

const focus = ([state]) => {
  const { editor } = state();
  if (!editor.hasFocus) {
    editor.focus();
  }
};

var Appearance = /* @__PURE__ */ ((Appearance2) => {
  Appearance2["Auto"] = "auto";
  Appearance2["Dark"] = "dark";
  Appearance2["Light"] = "light";
  return Appearance2;
})(Appearance || {});
var Markup = /* @__PURE__ */ ((Markup2) => {
  Markup2["Bold"] = "bold";
  Markup2["Code"] = "code";
  Markup2["CodeBlock"] = "code_block";
  Markup2["Heading"] = "heading";
  Markup2["Image"] = "image";
  Markup2["Italic"] = "italic";
  Markup2["Link"] = "link";
  Markup2["List"] = "list";
  Markup2["OrderedList"] = "ordered_list";
  Markup2["Quote"] = "quote";
  Markup2["TaskList"] = "task_list";
  return Markup2;
})(Markup || {});
var Selection = /* @__PURE__ */ ((Selection2) => {
  Selection2["End"] = "end";
  Selection2["Start"] = "start";
  return Selection2;
})(Selection || {});
const appearanceTypes = {
  auto: "auto",
  dark: "dark",
  light: "light"
};
const pluginTypes = {
  completion: "completion",
  default: "default",
  grammar: "grammar",
  language: "language"
};

const toCodeMirror = (selections) => {
  const ranges = selections.map((selection) => {
    const range = SelectionRange.fromJSON({ anchor: selection.start, head: selection.end });
    return range;
  });
  return EditorSelection.create(ranges);
};
const toInk = (selection) => {
  const selections = selection.ranges.map((range) => {
    return {
      end: range.anchor < range.head ? range.head : range.anchor,
      start: range.head < range.anchor ? range.head : range.anchor
    };
  });
  return selections;
};

const defineConfig$1 = (overrides) => {
  const defaults = {
    block: false,
    line: false,
    multiline: false,
    nodes: [],
    prefix: "",
    prefixStates: [],
    suffix: ""
  };
  return { ...defaults, ...overrides };
};
const formatting = {
  [Markup.Bold]: defineConfig$1({
    nodes: ["StrongEmphasis"],
    prefix: "**",
    suffix: "**"
  }),
  [Markup.Code]: defineConfig$1({
    nodes: ["InlineCode"],
    prefix: "`",
    suffix: "`"
  }),
  [Markup.CodeBlock]: defineConfig$1({
    block: true,
    nodes: ["FencedCode"],
    prefix: "```\n",
    suffix: "\n```"
  }),
  [Markup.Heading]: defineConfig$1({
    multiline: true,
    nodes: ["ATXHeading1", "ATXHeading2", "ATXHeading3", "ATXHeading4", "ATXHeading5", "ATXHeading6"],
    prefix: "# ",
    prefixStates: ["# ", "## ", "### ", "#### ", "##### ", "###### ", ""]
  }),
  [Markup.Image]: defineConfig$1({
    nodes: ["Image"],
    prefix: "![](",
    suffix: ")"
  }),
  [Markup.Italic]: defineConfig$1({
    nodes: ["Emphasis"],
    prefix: "*",
    suffix: "*"
  }),
  [Markup.Link]: defineConfig$1({
    nodes: ["Link"],
    prefix: "[](",
    suffix: ")"
  }),
  [Markup.OrderedList]: defineConfig$1({
    line: true,
    multiline: true,
    nodes: ["OrderedList"],
    prefix: "1. "
  }),
  [Markup.Quote]: defineConfig$1({
    line: true,
    multiline: true,
    nodes: ["Blockquote"],
    prefix: "> "
  }),
  [Markup.TaskList]: defineConfig$1({
    line: true,
    multiline: true,
    nodes: ["BulletList"],
    prefix: "- [ ] "
  }),
  [Markup.List]: defineConfig$1({
    line: true,
    multiline: true,
    nodes: ["BulletList"],
    prefix: "- "
  })
};
const splitSelectionByLines = ({ editor, selection }) => {
  let position = selection.start;
  const selections = [];
  while (position <= selection.end) {
    const line = editor.lineBlockAt(position);
    const start = Math.max(selection.start, line.from);
    const end = Math.min(selection.end, line.to);
    selections.push({ start, end });
    position = line.to + 1;
  }
  return selections;
};
const getSelection = ({ editor, formatDefinition, selection }) => {
  if (!editor || !formatDefinition)
    return selection || { start: 0, end: 0 };
  const initialSelection = selection || toInk(editor.state.selection).pop() || { start: 0, end: 0 };
  if (formatDefinition.block || formatDefinition.line || formatDefinition.multiline) {
    const start2 = editor.lineBlockAt(initialSelection.start).from;
    const end2 = editor.lineBlockAt(initialSelection.end).to;
    return { start: start2, end: end2 };
  }
  const start = editor.state.wordAt(initialSelection.start)?.from || initialSelection.start;
  const end = editor.state.wordAt(initialSelection.end)?.to || initialSelection.end;
  return { start, end };
};
const getText = (changeDetails) => {
  return changeDetails.editor.state.sliceDoc(changeDetails.selection.start, changeDetails.selection.end);
};
const getNode = (editor, definition, selection) => {
  const selectionNodes = getNodes(editor, selection);
  return selectionNodes.find(({ type }) => definition.nodes.includes(type.name));
};
const getNodes = (editor, selection) => {
  const nodeDefinitions = [];
  syntaxTree(editor.state).iterate({
    from: selection.start,
    to: selection.end,
    enter: ({ type, from, to }) => {
      nodeDefinitions.push({ type, from, to });
    }
  });
  return nodeDefinitions;
};
const unformat = (changeDetails) => {
  const text = getText(changeDetails);
  const sliceStart = changeDetails.formatDefinition.prefix.length;
  const sliceEnd = changeDetails.formatDefinition.suffix.length * -1 || text.length;
  const unformatted = text.slice(sliceStart, sliceEnd);
  return [{ from: changeDetails.selection.start, to: changeDetails.selection.end, insert: unformatted }];
};
const formatBlock = (changeDetails) => {
  if (changeDetails.node) {
    const start = changeDetails.node.from;
    const end = changeDetails.node.to;
    return unformat({ ...changeDetails, selection: { start, end } });
  } else {
    const before = changeDetails.formatDefinition.prefix;
    const after = changeDetails.formatDefinition.suffix;
    const changes = [
      { from: changeDetails.selection.start, insert: before },
      { from: changeDetails.selection.end, insert: after }
    ];
    return changes;
  }
};
const formatMultiline = (changeDetails) => {
  const selections = splitSelectionByLines(changeDetails);
  const changes = [];
  selections.forEach((selection) => {
    const lineChanges = formatLine({ ...changeDetails, selection });
    changes.push(...lineChanges);
  });
  return changes;
};
const formatLine = (changeDetails) => {
  const hasPrefixStates = changeDetails.formatDefinition.prefixStates.length > 0;
  const text = getText(changeDetails);
  if (changeDetails.node && hasPrefixStates) {
    const prefixState = changeDetails.formatDefinition.prefixStates.find((prefix) => text.startsWith(prefix));
    if (prefixState) {
      const prefixStateIndex = changeDetails.formatDefinition.prefixStates.indexOf(prefixState);
      const nextPrefixState = changeDetails.formatDefinition.prefixStates[prefixStateIndex + 1];
      const updatedText = text.replace(new RegExp(`^${prefixState}`), nextPrefixState);
      return [{ from: changeDetails.selection.start, to: changeDetails.selection.end, insert: updatedText }];
    }
  } else if (changeDetails.node && text.startsWith(changeDetails.formatDefinition.prefix)) {
    return unformat(changeDetails);
  }
  return [{ from: changeDetails.selection.start, insert: changeDetails.formatDefinition.prefix }];
};
const formatInline = (changeDetails) => {
  if (changeDetails.node) {
    const start = changeDetails.node.from;
    const end = changeDetails.node.to;
    return unformat({ ...changeDetails, selection: { start, end } });
  } else {
    const { formatDefinition, selection } = changeDetails;
    const before = Array.isArray(formatDefinition.prefix) ? formatDefinition.prefix[0] : formatDefinition.prefix;
    const after = formatDefinition.suffix;
    return [
      { from: selection.start, insert: before },
      { from: selection.end, insert: after }
    ];
  }
};
const getChanges = (changeDetails) => {
  if (changeDetails.formatDefinition.block) {
    return formatBlock(changeDetails);
  } else if (changeDetails.formatDefinition.multiline) {
    return formatMultiline(changeDetails);
  } else if (changeDetails.formatDefinition.line) {
    return formatLine(changeDetails);
  }
  return formatInline(changeDetails);
};
const format = ([state], formatType, { selection: maybeSelection } = {}) => {
  const { editor } = state();
  const formatDefinition = formatting[formatType];
  const selection = getSelection({ editor, formatDefinition, selection: maybeSelection });
  const node = getNode(editor, formatDefinition, selection);
  const changeDetails = {
    editor,
    formatDefinition,
    node,
    selection
  };
  const changes = getChanges(changeDetails);
  const offset = changes.reduce((total, change) => {
    const offset2 = change.insert.length - ((change.to || change.from) - change.from);
    return total + offset2;
  }, 0);
  const updates = state().editor.state.update({ changes, selection: { head: selection.start, anchor: selection.end + offset } });
  state().editor.dispatch(updates);
};

const getDoc = ([state]) => {
  const { editor } = state();
  return editor.state.sliceDoc();
};

const selections = ([state]) => {
  const { editor } = state();
  return toInk(editor.state.selection);
};

const insert = ([state, setState], text, selection, updateSelection = false) => {
  const { editor } = state();
  let start = selection?.start;
  let end = selection?.end || selection?.start;
  if (typeof start === "undefined") {
    const current = selections([state, setState]).pop();
    start = current.start;
    end = current.end;
  }
  const updates = { changes: { from: start, to: end, insert: text } };
  if (updateSelection) {
    const anchor = start === end ? start + text.length : start;
    const head = start === end ? start + text.length : start + text.length;
    Object.assign(updates, { selection: { anchor, head } });
  }
  editor.dispatch(
    editor.state.update(updates)
  );
};

const objectTypes = {
  array: "[object Array]",
  asyncFunction: "[object AsyncFunction]",
  boolean: "[object Boolean]",
  function: "[object Function]",
  null: "[object Null]",
  number: "[object Number]",
  object: "[object Object]",
  promise: "[object Promise]",
  string: "[object String]",
  symbol: "[object Symbol]",
  undefined: "[object Undefined]",
  window: "[object Window]"
};
const is$1 = (type, object) => {
  return Object.prototype.toString.call(object) === type;
};
const isPromise = (object) => is$1(objectTypes.promise, object);

const partitionPlugins = (plugins) => {
  return partition(plugins, isPromise);
};
const isPlugin = (pluginType, plugin) => {
  return plugin.type === pluginType;
};
const isOptionsKey = (key, options) => {
  return !!key && key in options;
};
const filterPlugins = (pluginType, options) => {
  return flatten(options.plugins).reduce((matches, plugin) => {
    if (isPlugin(pluginType, plugin)) {
      if (!plugin.key || isOptionsKey(plugin.key, options) && options[plugin.key]) {
        matches.push(plugin.value);
      }
    }
    return matches;
  }, []);
};
const flatten = (array) => {
  return array.reduce((flatArray, item) => {
    if (Array.isArray(item)) {
      return flatArray.concat(flatten(item));
    }
    return flatArray.concat(item);
  }, []);
};
const partition = (array, isValid) => {
  return array.reduce((partitions, entry) => {
    isValid(entry) ? partitions[0].push(entry) : partitions[1].push(entry);
    return partitions;
  }, [[], []]);
};

const makeExtension = ([state, setState]) => {
  const baseExtensions = [];
  const [lazyExtensions, extensions] = filterExtensions(state().options);
  const [lazyLanguages, languages$1] = filterLanguages(state().options);
  if (Math.max(lazyExtensions.length, lazyLanguages.length) > 0) {
    state().workQueue.enqueue(async () => {
      const effects = await buildVendorUpdates([state, setState]);
      state().editor.dispatch({ effects });
    });
  }
  return markdown$1({
    base: markdownLanguage,
    codeLanguages: [...languages, ...languages$1],
    extensions: [...baseExtensions, ...extensions]
  });
};
const filterExtensions = (options) => {
  return partitionPlugins(filterPlugins(pluginTypes.grammar, options));
};
const filterLanguages = (options) => {
  return partitionPlugins(filterPlugins(pluginTypes.language, options));
};
const updateExtension = async ([state]) => {
  const baseExtensions = [];
  const extensions = await Promise.all(filterPlugins(pluginTypes.grammar, state().options));
  const languages$1 = await Promise.all(filterPlugins(pluginTypes.language, state().options));
  return markdown$1({
    base: markdownLanguage,
    codeLanguages: [...languages, ...languages$1],
    extensions: [...baseExtensions, ...extensions]
  });
};
const markdown = () => {
  const compartment = new Compartment();
  return {
    compartment,
    initialValue: (store) => {
      return compartment.of(makeExtension(store));
    },
    reconfigure: async (store) => {
      return compartment.reconfigure(await updateExtension(store));
    }
  };
};

const createElement = () => {
  {
    return {};
  }
};
const isAutoDark = () => {
  {
    return true;
  }
};
const isDark = (appearance) => {
  if (appearance === Appearance.Dark)
    return true;
  if (appearance === Appearance.Light)
    return false;
  return isAutoDark();
};
const makeVars = (state) => {
  const styles = [
    // --ink-*
    { suffix: "border-radius", default: "0.25rem" },
    { suffix: "color", default: "currentColor" },
    { suffix: "flex-direction", default: "column" },
    { suffix: "font-family", default: "inherit" },
    // --ink-block-*
    { suffix: "block-background-color", default: "#121212", light: "#f5f5f5" },
    { suffix: "block-background-color-on-hover", default: "#0f0f0f", light: "#e0e0e0" },
    { suffix: "block-max-height", default: "20rem" },
    { suffix: "block-padding", default: "0.5rem" },
    // --ink-code-*
    { suffix: "code-background-color", default: "var(--ink-internal-block-background-color)" },
    { suffix: "code-color", default: "inherit" },
    { suffix: "code-font-family", default: "'Monaco', Courier, monospace" },
    // --ink-editor-*
    { suffix: "editor-font-size", default: "1em" },
    { suffix: "editor-line-height", default: "2em" },
    { suffix: "editor-padding", default: "0.5rem" },
    { suffix: "inline-padding", default: "0.125rem" },
    // --ink-modal-*
    { suffix: "modal-position", default: "fixed" },
    // --ink-syntax-*
    { suffix: "syntax-atom-color", default: "#d19a66" },
    { suffix: "syntax-comment-color", default: "#abb2bf" },
    { suffix: "syntax-comment-font-style", default: "italic" },
    { suffix: "syntax-emphasis-color", default: "inherit" },
    { suffix: "syntax-emphasis-font-style", default: "italic" },
    { suffix: "syntax-hashtag-background-color", default: "#222", light: "#eee" },
    { suffix: "syntax-hashtag-color", default: "inherit" },
    { suffix: "syntax-heading-color", default: "inherit" },
    { suffix: "syntax-heading-font-weight", default: "600" },
    { suffix: "syntax-heading1-color", default: "var(--ink-internal-syntax-heading-color, inherit)" },
    { suffix: "syntax-heading1-font-size", default: "1.6em" },
    { suffix: "syntax-heading1-font-weight", default: "600" },
    { suffix: "syntax-heading2-color", default: "var(--ink-internal-syntax-heading-color, inherit)" },
    { suffix: "syntax-heading2-font-size", default: "1.5em" },
    { suffix: "syntax-heading2-font-weight", default: "600" },
    { suffix: "syntax-heading3-color", default: "var(--ink-internal-syntax-heading-color, inherit)" },
    { suffix: "syntax-heading3-font-size", default: "1.4em" },
    { suffix: "syntax-heading3-font-weight", default: "600" },
    { suffix: "syntax-heading4-color", default: "var(--ink-internal-syntax-heading-color, inherit)" },
    { suffix: "syntax-heading4-font-size", default: "1.3em" },
    { suffix: "syntax-heading4-font-weight", default: "600" },
    { suffix: "syntax-heading5-color", default: "var(--ink-internal-syntax-heading-color, inherit)" },
    { suffix: "syntax-heading5-font-size", default: "1.2em" },
    { suffix: "syntax-heading5-font-weight", default: "600" },
    { suffix: "syntax-heading6-color", default: "var(--ink-internal-syntax-heading-color, inherit)" },
    { suffix: "syntax-heading6-font-size", default: "1.1em" },
    { suffix: "syntax-heading6-font-weight", default: "600" },
    { suffix: "syntax-highlight-background-color", default: "#555555" },
    { suffix: "syntax-keyword-color", default: "#c678dd" },
    { suffix: "syntax-link-color", default: "inherit" },
    { suffix: "syntax-meta-color", default: "#abb2bf" },
    { suffix: "syntax-monospace-color", default: "var(--ink-internal-code-color)" },
    { suffix: "syntax-monospace-font-family", default: "var(--ink-internal-code-font-family)" },
    { suffix: "syntax-name-color", default: "#d19a66" },
    { suffix: "syntax-name-label-color", default: "#abb2bf" },
    { suffix: "syntax-name-property-color", default: "#96c0d8" },
    { suffix: "syntax-name-property-definition-color", default: "#e06c75" },
    { suffix: "syntax-name-variable-color", default: "#e06c75" },
    { suffix: "syntax-name-variable-definition-color", default: "#e5c07b" },
    { suffix: "syntax-name-variable-local-color", default: "#d19a66" },
    { suffix: "syntax-name-variable-special-color", default: "inherit" },
    { suffix: "syntax-number-color", default: "#d19a66" },
    { suffix: "syntax-operator-color", default: "#96c0d8" },
    { suffix: "syntax-processing-instruction-color", default: "#444444", light: "#bbbbbb" },
    { suffix: "syntax-punctuation-color", default: "#abb2bf" },
    { suffix: "syntax-strikethrough-color", default: "inherit" },
    { suffix: "syntax-strikethrough-text-decoration", default: "line-through" },
    { suffix: "syntax-string-color", default: "#98c379" },
    { suffix: "syntax-string-special-color", default: "inherit" },
    { suffix: "syntax-strong-color", default: "inherit" },
    { suffix: "syntax-strong-font-weight", default: "600" },
    { suffix: "syntax-url-color", default: "#aaaaaa", light: "#666666" },
    { suffix: "toolbar-group-spacing", default: "2rem" },
    { suffix: "toolbar-item-spacing", default: "0" }
  ];
  const isLight = !isDark(state.options.interface.appearance);
  return styles.map((style) => {
    const value = isLight && style.light ? style.light : style.default;
    return `--ink-internal-${style.suffix}: var(--ink-${style.suffix}, ${value});`;
  });
};

const appearance = (isDark) => {
  return [
    EditorView.theme({
      ".cm-scroller": {
        fontFamily: "var(--ink-internal-font-family)"
      }
    }, { dark: isDark })
  ];
};

const buildVendors = ([state, setState]) => {
  const extensions = state().extensions.map((e) => e.initialValue([state, setState]));
  return extensions;
};
const buildVendorUpdates = async ([state, setState]) => {
  const effects = await Promise.all(
    state().extensions.map(async (extension2) => {
      return await extension2.reconfigure([state, setState]);
    })
  );
  return effects;
};
const extension = (resolver) => {
  const compartment = new Compartment();
  return {
    compartment,
    initialValue: (store) => {
      return compartment.of(resolver(store));
    },
    reconfigure: (store) => {
      return compartment.reconfigure(resolver(store));
    }
  };
};
const lazyExtension = (reconfigure) => {
  const compartment = new Compartment();
  return {
    compartment,
    initialValue: () => {
      return compartment.of([]);
    },
    reconfigure: (store) => {
      return reconfigure(store, compartment);
    }
  };
};
const createExtensions = () => {
  return [
    markdown(),
    ...resolvers.map((r) => extension(r)),
    ...lazyResolvers.map((r) => lazyExtension(r))
  ];
};
const resolvers = [
  ([state]) => {
    const [_lazyExtensions, extensions] = partitionPlugins(filterPlugins(pluginTypes.default, state().options));
    return extensions;
  },
  ([state]) => {
    const isDark = state().options.interface.appearance === appearanceTypes.dark;
    const isAuto = state().options.interface.appearance === appearanceTypes.auto;
    const extension2 = appearance(isDark || isAuto && isAutoDark());
    return extension2;
  }
];
const lazyResolvers = [
  async ([state], compartment) => {
    const [lazyExtensions] = partitionPlugins(filterPlugins(pluginTypes.default, state().options));
    if (lazyExtensions.length > 0) {
      return compartment.reconfigure(await Promise.all(lazyExtensions));
    }
    return compartment.reconfigure([]);
  },
  async ([state], compartment) => {
    if (state().options.interface.autocomplete) {
      const { autocomplete } = await import('./autocomplete-CWl6JKvL.js');
      return compartment.reconfigure(autocomplete(state().options));
    }
    return compartment.reconfigure([]);
  },
  async ([state], compartment) => {
    if (state().options.interface.images) {
      const { images } = await import('./images-28cKWC_1.js');
      return compartment.reconfigure(images());
    }
    return compartment.reconfigure([]);
  },
  async ([state], compartment) => {
    const { keybindings, trapTab } = state().options;
    const tab = trapTab ?? keybindings.tab;
    const shiftTab = trapTab ?? keybindings.shiftTab;
    if (tab || shiftTab) {
      const { indentWithTab } = await import('./indentWithTab-Cd1oYnbg.js');
      return compartment.reconfigure(indentWithTab({ tab, shiftTab }));
    }
    return compartment.reconfigure([]);
  },
  async ([state], compartment) => {
    const { options } = state();
    if (options.lists || options.interface.lists) {
      const { lists } = await import('./lists-0Uo7MaoR.js');
      let bullet = true;
      let number = true;
      let task = true;
      if (typeof options.lists === "object") {
        bullet = typeof options.lists.bullet === "undefined" ? false : options.lists.bullet;
        number = typeof options.lists.number === "undefined" ? false : options.lists.number;
        task = typeof options.lists.task === "undefined" ? false : options.lists.task;
      }
      return compartment.reconfigure(lists({ bullet, number, task }));
    }
    return compartment.reconfigure([]);
  },
  async ([state], compartment) => {
    if (state().options.placeholder) {
      const { placeholder } = await import('./placeholder-CwcNwbAs.js');
      return compartment.reconfigure(placeholder(state().options.placeholder));
    }
    return compartment.reconfigure([]);
  },
  async ([state], compartment) => {
    if (state().options.interface.readonly) {
      const { readonly } = await import('./readonly-C8c-FBkd.js');
      return compartment.reconfigure(readonly());
    }
    return compartment.reconfigure([]);
  },
  async ([state], compartment) => {
    if (state().options.search) {
      const { search } = await import('./search-Bi3Jw55E.js');
      return compartment.reconfigure(search());
    }
    return compartment.reconfigure([]);
  },
  async ([state], compartment) => {
    if (state().options.interface.spellcheck) {
      const { spellcheck } = await import('./spellcheck-C3EjCyxM.js');
      return compartment.reconfigure(spellcheck());
    }
    return compartment.reconfigure([]);
  },
  async ([state], compartment) => {
    if (state().options.vim) {
      const { vim } = await import('./vim-CikfFf6U.js');
      return compartment.reconfigure(vim());
    }
    return compartment.reconfigure([]);
  }
];

const blockquoteSyntaxNodes = [
  "Blockquote"
];
const blockquoteDecoration = Decoration.line({ attributes: { class: "cm-blockquote" } });
const blockquoteOpenDecoration = Decoration.line({ attributes: { class: "cm-blockquote-open" } });
const blockquoteCloseDecoration = Decoration.line({ attributes: { class: "cm-blockquote-close" } });
const blockquotePlugin = ViewPlugin.define((view) => {
  return {
    update: () => {
      return decorate$1(view);
    }
  };
}, { decorations: (plugin) => plugin.update() });
const decorate$1 = (view) => {
  const builder = new RangeSetBuilder();
  const tree = syntaxTree(view.state);
  for (const visibleRange of view.visibleRanges) {
    for (let position = visibleRange.from; position < visibleRange.to; ) {
      const line = view.state.doc.lineAt(position);
      tree.iterate({
        enter({ type, from, to }) {
          if (type.name !== "Document") {
            if (blockquoteSyntaxNodes.includes(type.name)) {
              builder.add(line.from, line.from, blockquoteDecoration);
              const openLine = view.state.doc.lineAt(from);
              const closeLine = view.state.doc.lineAt(to);
              if (openLine.number === line.number)
                builder.add(line.from, line.from, blockquoteOpenDecoration);
              if (closeLine.number === line.number)
                builder.add(line.from, line.from, blockquoteCloseDecoration);
              return false;
            }
          }
        },
        from: line.from,
        to: line.to
      });
      position = line.to + 1;
    }
  }
  return builder.finish();
};
const blockquote = () => {
  return [
    blockquotePlugin
  ];
};

const codeBlockSyntaxNodes = [
  "CodeBlock",
  "FencedCode",
  "HTMLBlock",
  "CommentBlock"
];
const sharedAttributes = {
  // Prevent spellcheck in all code blocks. The Grammarly extension might not respect these values.
  "data-enable-grammarly": "false",
  "data-gramm": "false",
  "data-grammarly-skip": "true",
  "spellcheck": "false"
};
const codeBlockDecoration = Decoration.line({ attributes: { ...sharedAttributes, class: "cm-codeblock" } });
const codeBlockOpenDecoration = Decoration.line({ attributes: { ...sharedAttributes, class: "cm-codeblock-open" } });
const codeBlockCloseDecoration = Decoration.line({ attributes: { ...sharedAttributes, class: "cm-codeblock-close" } });
const codeDecoration = Decoration.mark({ attributes: { ...sharedAttributes, class: "cm-code" } });
const codeOpenDecoration = Decoration.mark({ attributes: { ...sharedAttributes, class: "cm-code cm-code-open" } });
const codeCloseDecoration = Decoration.mark({ attributes: { ...sharedAttributes, class: "cm-code cm-code-close" } });
const codeBlockPlugin = ViewPlugin.define((view) => {
  return {
    update: () => {
      return decorate(view);
    }
  };
}, { decorations: (plugin) => plugin.update() });
const decorate = (view) => {
  const builder = new RangeSetBuilder();
  const tree = syntaxTree(view.state);
  for (const visibleRange of view.visibleRanges) {
    for (let position = visibleRange.from; position < visibleRange.to; ) {
      const line = view.state.doc.lineAt(position);
      let inlineCode;
      tree.iterate({
        enter({ type, from, to }) {
          if (type.name !== "Document") {
            if (codeBlockSyntaxNodes.includes(type.name)) {
              builder.add(line.from, line.from, codeBlockDecoration);
              const openLine = view.state.doc.lineAt(from);
              const closeLine = view.state.doc.lineAt(to);
              if (openLine.number === line.number)
                builder.add(line.from, line.from, codeBlockOpenDecoration);
              if (closeLine.number === line.number)
                builder.add(line.from, line.from, codeBlockCloseDecoration);
              return false;
            } else if (type.name === "InlineCode") {
              inlineCode = { from, to, innerFrom: from, innerTo: to };
            } else if (type.name === "CodeMark") {
              if (from === inlineCode.from) {
                inlineCode.innerFrom = to;
                builder.add(from, to, codeOpenDecoration);
              } else if (to === inlineCode.to) {
                inlineCode.innerTo = from;
                builder.add(inlineCode.innerFrom, inlineCode.innerTo, codeDecoration);
                builder.add(from, to, codeCloseDecoration);
              }
            }
          }
        },
        from: line.from,
        to: line.to
      });
      position = line.to + 1;
    }
  }
  return builder.finish();
};
const code = () => {
  return [
    codeBlockPlugin
  ];
};

const inkClassExtensions = () => {
  return [
    EditorView.editorAttributes.of({
      class: "ink-mde-container"
    }),
    EditorView.contentAttributes.of({
      class: "ink-mde-editor-content"
    })
    // Todo: Maybe open a PR to add scrollerAttributes?
  ];
};
const ink$1 = () => {
  return [
    ...inkClassExtensions()
  ];
};

const lineWrapping = () => {
  return EditorView.lineWrapping;
};

const theme = () => {
  const extension = syntaxHighlighting(
    HighlightStyle.define([
      // ordered by lowest to highest precedence
      {
        tag: tags.atom,
        color: "var(--ink-internal-syntax-atom-color)"
      },
      {
        tag: tags.meta,
        color: "var(--ink-internal-syntax-meta-color)"
      },
      // emphasis types
      {
        tag: tags.emphasis,
        color: "var(--ink-internal-syntax-emphasis-color)",
        fontStyle: "var(--ink-internal-syntax-emphasis-font-style)"
      },
      {
        tag: tags.strong,
        color: "var(--ink-internal-syntax-strong-color)",
        fontWeight: "var(--ink-internal-syntax-strong-font-weight)"
      },
      {
        tag: tags.strikethrough,
        color: "var(--ink-internal-syntax-strikethrough-color)",
        textDecoration: "var(--ink-internal-syntax-strikethrough-text-decoration)"
      },
      // comment group
      {
        tag: tags.comment,
        color: "var(--ink-internal-syntax-comment-color)",
        fontStyle: "var(--ink-internal-syntax-comment-font-style)"
      },
      // monospace
      {
        tag: tags.monospace,
        color: "var(--ink-internal-syntax-code-color)",
        fontFamily: "var(--ink-internal-syntax-code-font-family)"
      },
      // name group
      {
        tag: tags.name,
        color: "var(--ink-internal-syntax-name-color)"
      },
      {
        tag: tags.labelName,
        color: "var(--ink-internal-syntax-name-label-color)"
      },
      {
        tag: tags.propertyName,
        color: "var(--ink-internal-syntax-name-property-color)"
      },
      {
        tag: tags.definition(tags.propertyName),
        color: "var(--ink-internal-syntax-name-property-definition-color)"
      },
      {
        tag: tags.variableName,
        color: "var(--ink-internal-syntax-name-variable-color)"
      },
      {
        tag: tags.definition(tags.variableName),
        color: "var(--ink-internal-syntax-name-variable-definition-color)"
      },
      {
        tag: tags.local(tags.variableName),
        color: "var(--ink-internal-syntax-name-variable-local-color)"
      },
      {
        tag: tags.special(tags.variableName),
        color: "var(--ink-internal-syntax-name-variable-special-color)"
      },
      // headings
      {
        tag: tags.heading,
        color: "var(--ink-internal-syntax-heading-color)",
        fontWeight: "var(--ink-internal-syntax-heading-font-weight)"
      },
      {
        tag: tags.heading1,
        color: "var(--ink-internal-syntax-heading1-color)",
        fontSize: "var(--ink-internal-syntax-heading1-font-size)",
        fontWeight: "var(--ink-internal-syntax-heading1-font-weight)"
      },
      {
        tag: tags.heading2,
        color: "var(--ink-internal-syntax-heading2-color)",
        fontSize: "var(--ink-internal-syntax-heading2-font-size)",
        fontWeight: "var(--ink-internal-syntax-heading2-font-weight)"
      },
      {
        tag: tags.heading3,
        color: "var(--ink-internal-syntax-heading3-color)",
        fontSize: "var(--ink-internal-syntax-heading3-font-size)",
        fontWeight: "var(--ink-internal-syntax-heading3-font-weight)"
      },
      {
        tag: tags.heading4,
        color: "var(--ink-internal-syntax-heading4-color)",
        fontSize: "var(--ink-internal-syntax-heading4-font-size)",
        fontWeight: "var(--ink-internal-syntax-heading4-font-weight)"
      },
      {
        tag: tags.heading5,
        color: "var(--ink-internal-syntax-heading5-color)",
        fontSize: "var(--ink-internal-syntax-heading5-font-size)",
        fontWeight: "var(--ink-internal-syntax-heading5-font-weight)"
      },
      {
        tag: tags.heading6,
        color: "var(--ink-internal-syntax-heading6-color)",
        fontSize: "var(--ink-internal-syntax-heading6-font-size)",
        fontWeight: "var(--ink-internal-syntax-heading6-font-weight)"
      },
      // contextual tag types
      {
        tag: tags.keyword,
        color: "var(--ink-internal-syntax-keyword-color)"
      },
      {
        tag: tags.number,
        color: "var(--ink-internal-syntax-number-color)"
      },
      {
        tag: tags.operator,
        color: "var(--ink-internal-syntax-operator-color)"
      },
      {
        tag: tags.punctuation,
        color: "var(--ink-internal-syntax-punctuation-color)"
      },
      {
        tag: tags.link,
        color: "var(--ink-internal-syntax-link-color)",
        wordBreak: "break-all"
      },
      {
        tag: tags.url,
        color: "var(--ink-internal-syntax-url-color)",
        wordBreak: "break-all"
      },
      // string group
      {
        tag: tags.string,
        color: "var(--ink-internal-syntax-string-color)"
      },
      {
        tag: tags.special(tags.string),
        color: "var(--ink-internal-syntax-string-special-color)"
      },
      // processing instructions
      {
        tag: tags.processingInstruction,
        color: "var(--ink-internal-syntax-processing-instruction-color)"
      }
    ])
  );
  return [
    extension
  ];
};

const toVendorSelection = (selections) => {
  if (selections.length > 0) {
    return toCodeMirror(selections);
  }
};
const createState = ([state, setState]) => {
  const { selections } = state().options;
  return EditorState.create({
    doc: state().options.doc,
    selection: toVendorSelection(selections),
    extensions: [
      keymap.of([
        ...defaultKeymap,
        ...historyKeymap
      ]),
      blockquote(),
      code(),
      history(),
      ink$1(),
      lineWrapping(),
      theme(),
      ...buildVendors([state, setState])
    ]
  });
};

const types = {
  array: "[object Array]",
  object: "[object Object]",
  string: "[object String]",
  undefined: "[object Undefined]",
  window: "[object Window]"
};
const getType = (object) => {
  const type = Object.prototype.toString.call(object);
  if (type === types.object) {
    return `[object ${object.constructor.name}]`;
  }
};
const is = (object, type) => {
  return getType(object) === type;
};
const deepAssign = (target, source) => {
  const seen = /* @__PURE__ */ new WeakMap();
  const assign = (target2, source2) => {
    if (seen.get(target2))
      return target2;
    if (is(target2, types.object))
      seen.set(target2, true);
    if (is(source2, types.undefined))
      return target2;
    if (is(target2, types.array) && is(source2, types.array)) {
      return [...source2];
    }
    if (is(target2, types.object) && is(source2, types.object)) {
      return Object.keys(target2).reduce((replacement, key) => {
        if (Object.hasOwnProperty.call(source2, key)) {
          replacement[key] = assign(target2[key], source2[key]);
        } else {
          replacement[key] = target2[key];
        }
        return replacement;
      }, {});
    }
    return source2;
  };
  return assign(target, source);
};
const override = (a, b) => {
  return deepAssign(a, b);
};

const load = ([state, setState], doc) => {
  setState(override(state(), { options: { doc } }));
  state().editor.setState(createState([state, setState]));
};

const options = ([state]) => {
  return state().options;
};

const reconfigure = async ([state, setState], options) => {
  const { workQueue } = state();
  return workQueue.enqueue(async () => {
    setState(override(state(), { options }));
    const effects = await buildVendorUpdates([state, setState]);
    state().editor.dispatch({ effects });
  });
};

const select = (store, options = {}) => {
  if (options.selections)
    return selectMultiple(store, options.selections);
  if (options.selection)
    return selectOne(store, options.selection);
  if (options.at)
    return selectAt(store, options.at);
};
const selectAt = (store, at) => {
  const [state] = store;
  if (at === Selection.Start)
    return selectOne(store, { start: 0, end: 0 });
  if (at === Selection.End) {
    const position = state().editor.state.doc.length;
    return selectOne(store, { start: position, end: position });
  }
};
const selectMultiple = ([state], selections) => {
  const { editor } = state();
  editor.dispatch(
    editor.state.update({
      selection: toCodeMirror(selections)
    })
  );
};
const selectOne = (store, selection) => {
  return selectMultiple(store, [selection]);
};

const update = ([state], doc) => {
  const { editor } = state();
  editor.dispatch(
    editor.state.update({
      changes: {
        from: 0,
        to: editor.state.doc.length,
        insert: doc
      }
    })
  );
};

const wrap$1 = ([state, setState], { after, before, selection: userSelection }) => {
  const { editor } = state();
  const selection = userSelection || selections([state, setState]).pop() || { start: 0, end: 0 };
  const text = editor.state.sliceDoc(selection.start, selection.end);
  insert([state, setState], `${before}${text}${after}`, selection);
  select([state, setState], { selections: [{ start: selection.start + before.length, end: selection.end + before.length }] });
};

const awaitable = (initialValue, handler) => {
  const state = {
    callbacks: {
      fulfilled: [],
      rejected: [],
      settled: []
    },
    status: "pending"
  };
  const callback = (settler, { resolve: resolve2, reject: reject2 }) => {
    return () => {
      try {
        const settledValue = settler(state.value);
        Promise.resolve(settledValue).then(resolve2, reject2);
      } catch (error) {
        reject2(error);
      }
    };
  };
  const reject = (value) => {
    if (state.status === "pending") {
      state.status = "rejected";
      state.value = value;
      state.callbacks.rejected.forEach((callback2) => callback2());
      state.callbacks.settled.forEach((callback2) => callback2());
    }
  };
  const resolve = (value) => {
    if (state.status === "pending") {
      state.status = "fulfilled";
      state.value = value;
      state.callbacks.fulfilled.forEach((callback2) => callback2());
      state.callbacks.settled.forEach((callback2) => callback2());
    }
  };
  const then = (onFulfilled, onRejected) => {
    return new Promise((resolve2, reject2) => {
      if (state.status === "pending") {
        if (onFulfilled) {
          state.callbacks.fulfilled.push(callback(onFulfilled, { resolve: resolve2, reject: reject2 }));
        }
        if (onRejected) {
          state.callbacks.rejected.push(callback(onRejected, { resolve: void 0, reject: reject2 }));
        }
      }
      if (state.status === "fulfilled" && onFulfilled) {
        callback(onFulfilled, { resolve: resolve2, reject: reject2 })();
      }
      if (state.status === "rejected" && onRejected) {
        callback(onRejected, { resolve: void 0, reject: reject2 })();
      }
    });
  };
  queueMicrotask(() => {
    try {
      handler(resolve, reject);
    } catch (error) {
      reject(error);
    }
  });
  return {
    ...initialValue,
    [Symbol.toStringTag]: "awaitable",
    catch: then.bind(void 0, void 0),
    finally: (onSettled) => {
      return new Promise((resolve2, reject2) => {
        if (state.status === "pending") {
          state.callbacks.settled.push(callback(onSettled, { resolve: resolve2, reject: reject2 }));
        }
        if (state.status === "fulfilled") {
          onSettled();
          resolve2(state.value);
        }
        if (state.status === "rejected") {
          onSettled();
          reject2(state.value);
        }
      });
    },
    then
  };
};

const makeInstance = (store) => {
  const instance = {
    destroy: destroy.bind(void 0, store),
    focus: focus.bind(void 0, store),
    format: format.bind(void 0, store),
    getDoc: getDoc.bind(void 0, store),
    insert: insert.bind(void 0, store),
    load: load.bind(void 0, store),
    options: options.bind(void 0, store),
    reconfigure: reconfigure.bind(void 0, store),
    select: select.bind(void 0, store),
    selections: selections.bind(void 0, store),
    update: update.bind(void 0, store),
    wrap: wrap$1.bind(void 0, store)
  };
  return awaitable(instance, (resolve, reject) => {
    try {
      const [state] = store;
      state().workQueue.enqueue(() => resolve(instance));
    } catch (error) {
      reject(error);
    }
  });
};

const buildBlockWidgetDecoration = (options) => {
  return buildWidgetDecoration({
    block: true,
    side: -1,
    ...options
  });
};
const buildLineDecoration = (options) => {
  return Decoration.line({
    ...options,
    type: "line"
  });
};
const buildMarkDecoration = (options) => {
  return Decoration.mark({
    ...options,
    type: "mark"
  });
};
const buildWidget = (options) => {
  const eq = (other) => {
    if (options.eq)
      return options.eq(other);
    if (!options.id)
      return false;
    return options.id === other.id;
  };
  return {
    compare: (other) => {
      return eq(other);
    },
    coordsAt: () => null,
    destroy: () => {
    },
    eq: (other) => {
      return eq(other);
    },
    estimatedHeight: -1,
    ignoreEvent: () => true,
    lineBreaks: 0,
    toDOM: () => {
      return document.createElement("span");
    },
    updateDOM: () => false,
    ...options
  };
};
const buildWidgetDecoration = (options) => {
  return Decoration.widget({
    block: false,
    side: 0,
    ...options,
    widget: buildWidget({
      ...options.widget
    }),
    type: "widget"
  });
};
const buildNodeDecorations = (state, options) => {
  const decorationRanges = [];
  syntaxTree(state).iterate({
    enter: (node) => {
      if (options.nodes.includes(node.type.name)) {
        const maybeDecorations = options.onMatch(state, node);
        if (!maybeDecorations)
          return;
        const decorations = Array().concat(maybeDecorations);
        decorations.forEach((decoration) => {
          if (decoration.spec.type === "line") {
            const wrapped = buildLineDecoration({ ...decoration.spec, node: { ...node } });
            for (let line = state.doc.lineAt(node.from); line.from < node.to; line = state.doc.lineAt(line.to + 1)) {
              decorationRanges.push(wrapped.range(line.from));
              if (line.to === state.doc.length)
                break;
            }
          }
          if (decoration.spec.type === "mark") {
            const wrapped = buildMarkDecoration({ ...decoration.spec, node: { ...node } }).range(node.from, node.to);
            decorationRanges.push(wrapped);
          }
          if (decoration.spec.type === "widget") {
            const wrapped = buildWidgetDecoration({ ...decoration.spec, node: { ...node } }).range(node.from);
            decorationRanges.push(wrapped);
          }
        });
      }
    },
    from: options.range?.from,
    to: options.range?.to
  });
  return decorationRanges.sort((left, right) => {
    return left.from - right.from;
  });
};
const buildOptimizedNodeDecorations = (rangeSet, transaction, options) => {
  const decorations = [];
  const cursor = rangeSet.iter();
  const cursors = [];
  const cursorsToSkip = [];
  while (cursor.value) {
    cursors.push({ ...cursor });
    cursor.next();
  }
  transaction.changes.iterChangedRanges((_beforeFrom, _beforeTo, changeFrom, changeTo) => {
    cursors.forEach((cursor2) => {
      if (cursor2.value) {
        const nodeLength = cursor2.value.spec.node.to - cursor2.value.spec.node.from;
        const cursorFrom = cursor2.from;
        const cursorTo = cursor2.from + nodeLength;
        if (isOverlapping(cursorFrom, cursorTo, changeFrom, changeTo)) {
          cursorsToSkip.push(cursor2);
        }
      }
    });
    const range = { from: changeFrom, to: changeTo };
    decorations.push(...buildNodeDecorations(transaction.state, { ...options, range }));
  });
  const cursorDecos = cursors.filter((cursor2) => !cursorsToSkip.includes(cursor2)).flatMap((cursor2) => {
    const range = cursor2.value?.range(cursor2.from);
    if (!range)
      return [];
    return [range];
  });
  decorations.push(...cursorDecos);
  const allDecorations = decorations.sort((left, right) => {
    return left.from - right.from;
  });
  return allDecorations;
};
const isOverlapping = (x1, x2, y1, y2) => {
  return Math.max(x1, y1) <= Math.min(x2, y2);
};
const nodeDecorator = (options) => {
  return StateField.define({
    create(state) {
      return RangeSet.of(buildNodeDecorations(state, options));
    },
    update(rangeSet, transaction) {
      if (transaction.reconfigured || transaction.effects.length > 0) {
        return RangeSet.of(buildNodeDecorations(transaction.state, options));
      }
      const updatedRangeSet = rangeSet.map(transaction.changes);
      if (transaction.docChanged) {
        if (options.optimize) {
          return RangeSet.of(buildOptimizedNodeDecorations(updatedRangeSet, transaction, options));
        }
        return RangeSet.of(buildNodeDecorations(transaction.state, options));
      }
      return updatedRangeSet;
    },
    provide(field) {
      return EditorView.decorations.from(field);
    }
  });
};

const buildTag = (parent) => {
  return Tag.define(parent);
};
const getCharCode = (char) => {
  return char.charCodeAt(0);
};

const buildMarkNode = (markName) => {
  return buildTaggedNode(markName, [tags.processingInstruction]);
};
const buildTaggedNode = (nodeName, styleTags = []) => {
  const tag = buildTag();
  const node = defineNode({
    name: nodeName,
    style: [tag, ...styleTags]
  });
  return {
    node,
    tag
  };
};
const defineBlockParser = (options) => options;
const defineInlineParser = (options) => options;
const defineMarkdown = (options) => options;
const defineNode = (options) => options;

const charCodes = {
  dollarSign: getCharCode("$")
};
const mathInlineTestRegex = /\$.*?\$/;
const mathInlineCaptureRegex = /\$(?<math>.*?)\$/;
const mathInline = buildTaggedNode("MathInline");
const mathInlineMark = buildMarkNode("MathInlineMark");
const mathInlineMarkOpen = buildMarkNode("MathInlineMarkOpen");
const mathInlineMarkClose = buildMarkNode("MathInlineMarkClose");
const mathInlineParser = defineInlineParser({
  name: mathInline.node.name,
  parse: (inlineContext, nextCharCode, position) => {
    if (nextCharCode !== charCodes.dollarSign)
      return -1;
    const remainingLineText = inlineContext.slice(position, inlineContext.end);
    if (!mathInlineTestRegex.test(remainingLineText))
      return -1;
    const match = remainingLineText.match(mathInlineCaptureRegex);
    if (!match?.groups?.math)
      return -1;
    const mathExpressionLength = match.groups.math.length;
    return inlineContext.addElement(
      inlineContext.elt(
        mathInline.node.name,
        position,
        position + mathExpressionLength + 2,
        [
          inlineContext.elt(
            mathInlineMark.node.name,
            position,
            position + 1,
            [
              inlineContext.elt(
                mathInlineMarkOpen.node.name,
                position,
                position + 1
              )
            ]
          ),
          inlineContext.elt(
            mathInlineMark.node.name,
            position + mathExpressionLength + 1,
            position + mathExpressionLength + 2,
            [
              inlineContext.elt(
                mathInlineMarkClose.node.name,
                position + mathExpressionLength + 1,
                position + mathExpressionLength + 2
              )
            ]
          )
        ]
      )
    );
  }
});
const mathBlock = buildTaggedNode("MathBlock");
const mathBlockMark = buildMarkNode("MathBlockMark");
const mathBlockMarkOpen = buildMarkNode("MathBlockMarkOpen");
const mathBlockMarkClose = buildMarkNode("MathBlockMarkClose");
const mathBlockParser = defineBlockParser({
  name: "MathBlock",
  parse: (blockContext, line) => {
    if (line.next !== charCodes.dollarSign)
      return false;
    if (line.text.charCodeAt(line.pos + 1) !== charCodes.dollarSign)
      return false;
    const openLineStart = blockContext.lineStart + line.pos;
    const openLineEnd = openLineStart + line.text.length;
    while (blockContext.nextLine()) {
      if (line.next === charCodes.dollarSign && line.text.charCodeAt(line.pos + 1) === charCodes.dollarSign) {
        const closeLineStart = blockContext.lineStart + line.pos;
        const closeLineEnd = closeLineStart + line.text.length;
        blockContext.addElement(
          blockContext.elt(
            mathBlock.node.name,
            openLineStart,
            closeLineEnd,
            [
              blockContext.elt(
                mathBlockMark.node.name,
                openLineStart,
                openLineEnd,
                [
                  blockContext.elt(
                    mathBlockMarkOpen.node.name,
                    openLineStart,
                    openLineEnd
                  )
                ]
              ),
              blockContext.elt(
                mathBlockMark.node.name,
                closeLineStart,
                closeLineEnd,
                [
                  blockContext.elt(
                    mathBlockMarkClose.node.name,
                    closeLineStart,
                    closeLineEnd
                  )
                ]
              )
            ]
          )
        );
        blockContext.nextLine();
        break;
      }
    }
    return true;
  }
});
const grammar = defineMarkdown({
  defineNodes: [
    mathInline.node,
    mathInlineMark.node,
    mathInlineMarkClose.node,
    mathInlineMarkOpen.node,
    mathBlock.node,
    mathBlockMark.node,
    mathBlockMarkOpen.node,
    mathBlockMarkClose.node
  ],
  parseBlock: [
    mathBlockParser
  ],
  parseInline: [
    mathInlineParser
  ]
});

const katex = () => {
  return [
    plugin({
      key: "katex",
      type: pluginTypes.grammar,
      value: async () => grammar
    }),
    plugin({
      key: "katex",
      value: async () => {
        return nodeDecorator({
          nodes: ["MathBlock", "MathBlockMarkClose", "MathBlockMarkOpen"],
          onMatch: (_state, node) => {
            const classes = ["ink-mde-line-math-block"];
            if (node.name === "MathBlockMarkOpen")
              classes.push("ink-mde-line-math-block-open");
            if (node.name === "MathBlockMarkClose")
              classes.push("ink-mde-line-math-block-close");
            return buildLineDecoration({
              attributes: {
                class: classes.join(" ")
              }
            });
          },
          optimize: false
        });
      }
    }),
    plugin({
      key: "katex",
      value: async () => {
        return nodeDecorator({
          nodes: ["MathBlock"],
          onMatch: (state, node) => {
            const text = state.sliceDoc(node.from, node.to).split("\n").slice(1, -1).join("\n");
            if (text) {
              return buildBlockWidgetDecoration({
                widget: buildWidget({
                  id: text,
                  toDOM: (view) => {
                    const container = document.createElement("div");
                    const katexTarget = document.createElement("div");
                    container.className = "ink-mde-block-widget-container";
                    katexTarget.className = "ink-mde-block-widget ink-mde-katex-target";
                    container.appendChild(katexTarget);
                    import('katex').then(({ default: lib }) => {
                      lib.render(text, katexTarget, { output: "html", throwOnError: false });
                      view.requestMeasure();
                    });
                    return container;
                  },
                  updateDOM: (dom, view) => {
                    const katexTarget = dom.querySelector(".ink-mde-katex-target");
                    if (katexTarget) {
                      import('katex').then(({ default: lib }) => {
                        lib.render(text, katexTarget, { output: "html", throwOnError: false });
                        view.requestMeasure();
                      });
                      return true;
                    }
                    return false;
                  }
                })
              });
            }
          },
          optimize: false
        });
      }
    }),
    plugin({
      key: "katex",
      value: async () => {
        return syntaxHighlighting(
          HighlightStyle.define([
            {
              tag: [mathInline.tag, mathInlineMark.tag],
              backgroundColor: "var(--ink-internal-block-background-color)"
            },
            {
              tag: [mathInlineMarkClose.tag],
              backgroundColor: "var(--ink-internal-block-background-color)",
              borderRadius: "0 var(--ink-internal-border-radius) var(--ink-internal-border-radius) 0",
              paddingRight: "var(--ink-internal-inline-padding)"
            },
            {
              tag: [mathInlineMarkOpen.tag],
              backgroundColor: "var(--ink-internal-block-background-color)",
              borderRadius: "var(--ink-internal-border-radius) 0 0 var(--ink-internal-border-radius)",
              paddingLeft: "var(--ink-internal-inline-padding)"
            }
          ])
        );
      }
    }),
    plugin({
      key: "katex",
      value: async () => {
        return EditorView.theme({
          ".ink-mde-line-math-block": {
            backgroundColor: "var(--ink-internal-block-background-color)",
            padding: "0 var(--ink-internal-block-padding) !important"
          },
          ".ink-mde-line-math-block-open": {
            borderRadius: "var(--ink-internal-border-radius) var(--ink-internal-border-radius) 0 0"
          },
          ".ink-mde-line-math-block-close": {
            borderRadius: "0 0 var(--ink-internal-border-radius) var(--ink-internal-border-radius)"
          }
        });
      }
    })
  ];
};

const makeQueue = () => {
  const state = {
    queue: [],
    workload: 0
  };
  const process = async () => {
    const task = state.queue.pop();
    if (!task)
      return;
    await task();
    state.workload--;
    await process();
  };
  return {
    enqueue: (callback) => {
      return new Promise((resolve, reject) => {
        const task = async () => {
          try {
            await callback();
            resolve();
          } catch (error) {
            reject(error);
          }
        };
        state.queue.push(task);
        state.workload++;
        if (state.workload > 1)
          return;
        process();
      });
    }
  };
};

const blankState = () => {
  const options = {
    doc: "",
    files: {
      clipboard: false,
      dragAndDrop: false,
      handler: () => {
      },
      injectMarkup: true,
      types: ["image/*"]
    },
    hooks: {
      afterUpdate: () => {
      },
      beforeUpdate: () => {
      }
    },
    interface: {
      appearance: Appearance.Auto,
      attribution: true,
      autocomplete: false,
      images: false,
      lists: false,
      readonly: false,
      spellcheck: true,
      toolbar: false
    },
    katex: false,
    keybindings: {
      // Todo: Set these to false by default. https://codemirror.net/examples/tab
      tab: true,
      shiftTab: true
    },
    lists: false,
    placeholder: "",
    plugins: [
      katex()
    ],
    readability: false,
    search: true,
    selections: [],
    toolbar: {
      bold: true,
      code: true,
      codeBlock: true,
      heading: true,
      image: true,
      italic: true,
      link: true,
      list: true,
      orderedList: true,
      quote: true,
      taskList: true,
      upload: false
    },
    // This value overrides both `tab` and `shiftTab` keybindings.
    trapTab: void 0,
    vim: false
  };
  return {
    doc: "",
    editor: {},
    extensions: createExtensions(),
    options,
    root: createElement(),
    target: createElement(),
    workQueue: makeQueue()
  };
};
const makeState = (partialState) => {
  return override(blankState(), partialState);
};
const makeStore = (options, overrides = {}) => {
  const [state, setState] = createSignal(makeState({ ...overrides, doc: options.doc || "", options }));
  return [state, setState];
};

const DEFAULT_WORDS_PER_MINUTE = 225;
const toHuman = (text, wordsPerMinute = DEFAULT_WORDS_PER_MINUTE) => {
  const readTime = toHumanReadTime(text, wordsPerMinute);
  const wordCount = toHumanWordCount(text);
  const lineCount = toHumanLineCount(text);
  const charCount = toHumanCharCount(text);
  return [readTime, wordCount, lineCount, charCount].join(" | ");
};
const toHumanCharCount = (text) => {
  const charCount = toCharCount(text);
  return `${charCount} chars`;
};
const toHumanLineCount = (text) => {
  const lineCount = toLineCount(text);
  return `${lineCount} lines`;
};
const toHumanReadTime = (text, wordsPerMinute = DEFAULT_WORDS_PER_MINUTE) => {
  const readTime = toReadTime(text, wordsPerMinute);
  const readTimeMinutes = Math.floor(readTime);
  const readTimeSeconds = Math.floor(readTime % 1 * 60);
  if (readTimeMinutes === 0) {
    return `${readTimeSeconds}s read`;
  }
  return `${readTimeMinutes}m ${readTimeSeconds}s to read`;
};
const toHumanWordCount = (text) => {
  const wordCount = toWordCount(text);
  return `${wordCount} words`;
};
const toCharCount = (text) => {
  return text.length;
};
const toLineCount = (text) => {
  return text.split(/\n/).length;
};
const toReadTime = (text, wordsPerMinute = DEFAULT_WORDS_PER_MINUTE) => {
  return toWordCount(text) / wordsPerMinute;
};
const toWordCount = (text) => {
  const scrubbed = text.replace(/[']/g, "").replace(/[^\w\d]+/g, " ").trim();
  if (!scrubbed) {
    return 0;
  }
  return scrubbed.split(/\s+/).length;
};

var _tmpl$$7 = ["<div", " class=\"ink-mde-readability\"><span>", "</span></div>"],
  _tmpl$2$2 = ["<span", ">&nbsp;|</span>"],
  _tmpl$3$2 = ["<div", " class=\"ink-mde-attribution\"><span>&nbsp;powered by <a class=\"ink-mde-attribution-link\" href=\"https://github.com/davidmyersdev/ink-mde\" rel=\"noopener noreferrer\" target=\"_blank\">ink-mde</a></span></div>"],
  _tmpl$4$2 = ["<div", " class=\"ink-mde-details\"><div class=\"ink-mde-container\"><div class=\"ink-mde-details-content\"><!--$-->", "<!--/--><!--$-->", "<!--/--><!--$-->", "<!--/--></div></div></div>"];
const Details = () => {
  const [state] = useStore();
  return ssr(_tmpl$4$2, ssrHydrationKey(), escape(createComponent(Show, {
    get when() {
      return state().options.readability;
    },
    get children() {
      return ssr(_tmpl$$7, ssrHydrationKey(), escape(toHuman(state().doc)));
    }
  })), escape(createComponent(Show, {
    get when() {
      return state().options.readability && state().options.interface.attribution;
    },
    get children() {
      return ssr(_tmpl$2$2, ssrHydrationKey());
    }
  })), escape(createComponent(Show, {
    get when() {
      return state().options.interface.attribution;
    },
    get children() {
      return ssr(_tmpl$3$2, ssrHydrationKey());
    }
  })));
};

const styles$2 = ".ink-drop-zone {\n  align-items: center;\n  background-color: rgba(0, 0, 0, 0.5);\n  color: var(--ink-internal-color);\n  display: flex;\n  inset: 0;\n  justify-content: center;\n  position: var(--ink-internal-modal-position);\n  z-index: 100;\n}\n\n.ink-drop-zone:not(.visible) {\n  display: none;\n}\n\n.ink-drop-zone-modal {\n  background-color: var(--ink-internal-block-background-color);\n  border-radius: var(--ink-internal-border-radius);\n  box-sizing: border-box;\n  height: 100%;\n  max-height: 20rem;\n  max-width: 40rem;\n  padding: 1rem;\n  position: relative;\n  width: 100%;\n}\n\n.ink-drop-zone-hide {\n  cursor: pointer;\n  height: 1.75rem;\n  position: absolute;\n  right: 0.25rem;\n  top: 0.25rem;\n  width: 1.75rem;\n}\n\n.ink-drop-zone-hide svg {\n  background-color: var(--ink-internal-block-background-color);\n}\n\n.ink-drop-zone-droppable-area {\n  align-items: center;\n  border: 0.2rem dashed var(--ink-internal-color);\n  border-radius: 0.125rem;\n  box-sizing: border-box;\n  display: flex;\n  flex-direction: column;\n  font-size: 1.25em;\n  gap: 1rem;\n  height: 100%;\n  justify-content: center;\n  padding: 1rem;\n  text-align: center;\n}\n\n.ink-drop-zone-file-preview {\n  align-items: center;\n  display: flex;\n  flex-wrap: wrap;\n  gap: 0.5rem;\n  max-width: 25.5rem;\n}\n\n.ink-drop-zone-file-preview-image {\n  border: 0.125rem solid #222;\n  border-radius: 0.125rem;\n  box-sizing: border-box;\n  height: 6rem;\n  object-fit: cover;\n  padding: 0.5rem;\n  width: 6rem;\n}\n";

var _tmpl$$6 = ["<span", ">uploading files...</span>"],
  _tmpl$2$1 = ["<div", " class=\"", "\"><style>", "</style><div class=\"ink-drop-zone-modal\"><div class=\"ink-drop-zone-droppable-area\"><div class=\"ink-drop-zone-file-preview\">", "</div><!--$-->", "<!--/--></div><div class=\"ink-drop-zone-hide\"><svg xmlns=\"http://www.w3.org/2000/svg\" fill=\"none\" viewBox=\"0 0 24 24\" stroke=\"currentColor\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z\"></path></svg></div></div></div>"],
  _tmpl$3$1 = ["<img", " class=\"ink-drop-zone-file-preview-image\"", ">"],
  _tmpl$4$1 = ["<span", ">drop files here</span>"];
const DropZone = () => {
  const [depth, setDepth] = createSignal(0);
  const [files, setFiles] = createSignal([]);
  const [isLoading, setIsLoading] = createSignal(false);
  const [isVisible, setIsVisible] = createSignal(false);
  const [state, setState] = useStore();
  const onDragEnter = event => {
    if (state().options.files.dragAndDrop) {
      event.preventDefault();
      setDepth(depth() + 1);
      setIsVisible(true);
    }
  };
  const onDragLeave = event => {
    if (state().options.files.dragAndDrop) {
      event.preventDefault();
      setDepth(depth() - 1);
      if (depth() === 0) setIsVisible(false);
    }
  };
  const onDragOver = event => {
    if (state().options.files.dragAndDrop) {
      event.preventDefault();
      setIsVisible(true);
    }
  };
  const onDrop = event => {
    if (state().options.files.dragAndDrop) {
      event.preventDefault();
      setDepth(0);
      setIsVisible(false);
    }
  };
  const onPaste = event => {
    if (state().options.files.clipboard) {
      event.preventDefault();
      const transfer = event.clipboardData;
      if (transfer?.files && transfer.files.length > 0) uploadFiles(transfer.files);
    }
  };
  const uploadFiles = userFiles => {
    Array.from(userFiles).forEach(file => {
      setFiles([...files(), file]);
    });
    setIsLoading(true);
    setIsVisible(true);
    Promise.resolve(state().options.files.handler(userFiles)).then(url => {
      if (state().options.files.injectMarkup && url) {
        const markup = `![](${url})`;
        insert([state, setState], markup);
      }
    }).finally(() => {
      setDepth(0);
      setIsLoading(false);
      setIsVisible(false);
      setFiles([]);
    });
  };
  onMount(() => {
    document.addEventListener('dragenter', onDragEnter);
    document.addEventListener('dragleave', onDragLeave);
    document.addEventListener('dragover', onDragOver);
    document.addEventListener('drop', onDrop);
    state().root.addEventListener('paste', onPaste);
  });
  onCleanup(() => {
    document.removeEventListener('dragenter', onDragEnter);
    document.removeEventListener('dragleave', onDragLeave);
    document.removeEventListener('dragover', onDragOver);
    document.removeEventListener('drop', onDrop);
    state().root.removeEventListener('paste', onPaste);
  });
  return ssr(_tmpl$2$1, ssrHydrationKey(), `ink-drop-zone ${isVisible() ? "visible" : ""}`, styles$2 , escape(createComponent(For, {
    get each() {
      return files().slice(0, 8);
    },
    children: file => ssr(_tmpl$3$1, ssrHydrationKey(), ssrAttribute("alt", escape(file.name, true), false) + ssrAttribute("src", escape(URL.createObjectURL(file), true), false))
  })), escape(createComponent(Show, {
    get when() {
      return isLoading();
    },
    get fallback() {
      return ssr(_tmpl$4$1, ssrHydrationKey());
    },
    get children() {
      return ssr(_tmpl$$6, ssrHydrationKey());
    }
  })));
};

var _tmpl$$5 = ["<div", ' class="cm-editor"><div class="cm-scroller"><div class="cm-content" contenteditable="true"><div class="cm-line"><br></div></div></div></div>'];
const Editor = (props) => {
  {
    return ssr(_tmpl$$5, ssrHydrationKey());
  }
};

var _tmpl$$4 = ["<button", " class=\"ink-button\" type=\"button\">", "</button>"];
const Button = props => {
  return ssr(_tmpl$$4, ssrHydrationKey(), escape(props.children));
};

const styles$1 = ".ink-mde .ink-mde-toolbar {\n  background-color: var(--ink-internal-block-background-color);\n  color: inherit;\n  display: flex;\n  flex-shrink: 0;\n  overflow-x: auto;\n  padding: 0.25rem;\n}\n\n.ink-mde .ink-mde-toolbar .ink-mde-container {\n  display: flex;\n  gap: var(--ink-internal-toolbar-group-spacing);\n}\n\n.ink-mde .ink-mde-toolbar-group {\n  display: flex;\n  gap: var(--ink-internal-toolbar-item-spacing);\n}\n\n.ink-mde .ink-mde-toolbar .ink-button {\n  align-items: center;\n  background: none;\n  border: none;\n  border-radius: var(--ink-internal-border-radius);\n  color: inherit;\n  cursor: pointer;\n  display: flex;\n  height: 2.25rem;\n  justify-content: center;\n  padding: 0.4rem;\n  width: 2.25rem;\n}\n\n.ink-mde .ink-mde-toolbar .ink-button:hover {\n  background-color: var(--ink-internal-block-background-color-on-hover);\n}\n\n.ink-mde .ink-mde-toolbar .ink-button > * {\n  align-items: center;\n  display: flex;\n  height: 100%;\n}\n";

var _tmpl$$3 = ["<svg", " viewBox=\"0 0 20 20\" fill=\"none\" stroke=\"currentColor\" stroke-miterlimit=\"5\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M6 4V10M6 16V10M6 10H14M14 10V4M14 10V16\"></path></svg>"],
  _tmpl$2 = ["<svg", " viewBox=\"0 0 20 20\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.5\" stroke-miterlimit=\"5\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M6.5 10H10.5C12.1569 10 13.5 11.3431 13.5 13C13.5 14.6569 12.1569 16 10.5 16H6.5V4H9.5C11.1569 4 12.5 5.34315 12.5 7C12.5 8.65686 11.1569 10 9.5 10\"></path></svg>"],
  _tmpl$3 = ["<svg", " viewBox=\"0 0 20 20\" fill=\"none\" stroke=\"currentColor\" stroke-miterlimit=\"5\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M11 4L9 16M13 4H9M7 16H11\"></path></svg>"],
  _tmpl$4 = ["<div", " class=\"ink-mde-toolbar-group\"><!--$-->", "<!--/--><!--$-->", "<!--/--><!--$-->", "<!--/--></div>"],
  _tmpl$5 = ["<svg", " viewBox=\"0 0 20 20\" fill=\"none\" stroke=\"currentColor\" stroke-miterlimit=\"5\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M2.00257 16H17.9955M2.00055 4H18M7 10H18.0659M2 8.5V11.4999C2.4 11.5 2.5 11.5 2.5 11.5V11V10.5M4 8.5V11.4999H4.5V11V10.5\"></path></svg>"],
  _tmpl$6 = ["<svg", " viewBox=\"0 0 20 20\" fill=\"none\" stroke=\"currentColor\" stroke-miterlimit=\"5\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M13 4L7 16\"></path><path d=\"M5 7L2 10L5 13\"></path><path d=\"M15 7L18 10L15 13\"></path></svg>"],
  _tmpl$7 = ["<svg", " viewBox=\"0 0 20 20\" fill=\"none\" stroke=\"currentColor\" stroke-miterlimit=\"5\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M7 4L8 6\"></path></svg>"],
  _tmpl$8 = ["<svg", " viewBox=\"0 0 20 20\" fill=\"none\" stroke=\"currentColor\" stroke-miterlimit=\"5\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M7 16H17.8294\"></path><path d=\"M2 16H4\"></path><path d=\"M7 10H17.8294\"></path><path d=\"M2 10H4\"></path><path d=\"M7 4H17.8294\"></path><path d=\"M2 4H4\"></path></svg>"],
  _tmpl$9 = ["<svg", " viewBox=\"0 0 20 20\" fill=\"none\" stroke=\"currentColor\" stroke-miterlimit=\"5\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M7 16H18\"></path><path d=\"M2 17.0242C2.48314 17.7569 3.94052 17.6154 3.99486 16.7919C4.05315 15.9169 3.1975 16.0044 2.99496 16.0044M2.0023 14.9758C2.48544 14.2431 3.94282 14.3846 3.99716 15.2081C4.05545 16.0831 3.1998 16.0002 2.99726 16.0002\"></path><path d=\"M7 10H18\"></path><path d=\"M2.00501 11.5H4M2.00193 8.97562C2.48449 8.24319 3.9401 8.38467 3.99437 9.20777C4.05259 10.0825 2.04342 10.5788 2 11.4996\"></path><path d=\"M7 4H18\"></path><path d=\"M2 5.5H4M2.99713 5.49952V2.5L2.215 2.93501\"></path></svg>"],
  _tmpl$10 = ["<svg", " viewBox=\"0 0 20 20\" fill=\"none\" stroke=\"currentColor\" stroke-miterlimit=\"5\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M7 16H17.8294\"></path><path d=\"M5 15L3 17L2 16\"></path><path d=\"M7 10H17.8294\"></path><path d=\"M5 9L3 11L2 10\"></path><path d=\"M7 4H17.8294\"></path><path d=\"M5 3L3 5L2 4\"></path></svg>"],
  _tmpl$11 = ["<svg", " viewBox=\"0 0 20 20\" fill=\"none\" stroke=\"currentColor\" stroke-miterlimit=\"5\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M9.12127 10.881C10.02 11.78 11.5237 11.7349 12.4771 10.7813L15.2546 8.00302C16.2079 7.04937 16.253 5.54521 15.3542 4.6462C14.4555 3.74719 12.9512 3.79174 11.9979 4.74539L10.3437 6.40007M10.8787 9.11903C9.97997 8.22002 8.47626 8.26509 7.52288 9.21874L4.74545 11.997C3.79208 12.9506 3.74701 14.4548 4.64577 15.3538C5.54452 16.2528 7.04876 16.2083 8.00213 15.2546L9.65633 13.5999\"></path></svg>"],
  _tmpl$12 = ["<svg", " viewBox=\"0 0 20 20\" fill=\"none\" stroke=\"currentColor\" stroke-miterlimit=\"5\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><rect x=\"2\" y=\"4\" width=\"16\" height=\"12\" rx=\"1\"></rect><path d=\"M7.42659 7.67597L13.7751 13.8831M2.00208 12.9778L7.42844 7.67175\"></path><path d=\"M11.9119 12.0599L14.484 9.54443L17.9973 12.9785\"></path><path d=\"M10.9989 7.95832C11.551 7.95832 11.9986 7.52072 11.9986 6.98092C11.9986 6.44113 11.551 6.00354 10.9989 6.00354C10.4468 6.00354 9.99921 6.44113 9.99921 6.98092C9.99921 7.52072 10.4468 7.95832 10.9989 7.95832Z\"></path></svg>"],
  _tmpl$13 = ["<svg", " viewBox=\"0 0 20 20\" fill=\"none\" stroke=\"currentColor\" stroke-miterlimit=\"5\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M10 13V4M10 4L13 7M10 4L7 7\"></path><path d=\"M2 13V15C2 15.5523 2.44772 16 3 16H17C17.5523 16 18 15.5523 18 15V13\"></path></svg>"],
  _tmpl$14 = ["<input", " style=\"", "\" type=\"file\">"],
  _tmpl$15 = ["<div", " class=\"ink-mde-toolbar\"><style>", "</style><div class=\"ink-mde-container\"><!--$-->", "<!--/--><!--$-->", "<!--/--><!--$-->", "<!--/--><!--$-->", "<!--/--></div></div>"];
const Toolbar = () => {
  const [state, setState] = useStore();
  const [uploader, setUploader] = createSignal();
  const formatAs = type => {
    format([state, setState], type);
    focus([state, setState]);
  };
  const uploadClickHandler = () => {
    uploader()?.click();
  };
  return ssr(_tmpl$15, ssrHydrationKey(), styles$1 , escape(createComponent(Show, {
    get when() {
      return state().options.toolbar.heading || state().options.toolbar.bold || state().options.toolbar.italic;
    },
    get children() {
      return ssr(_tmpl$4, ssrHydrationKey(), escape(createComponent(Show, {
        get when() {
          return state().options.toolbar.heading;
        },
        get children() {
          return createComponent(Button, {
            onclick: () => formatAs(Markup.Heading),
            get children() {
              return ssr(_tmpl$$3, ssrHydrationKey());
            }
          });
        }
      })), escape(createComponent(Show, {
        get when() {
          return state().options.toolbar.bold;
        },
        get children() {
          return createComponent(Button, {
            onclick: () => formatAs(Markup.Bold),
            get children() {
              return ssr(_tmpl$2, ssrHydrationKey());
            }
          });
        }
      })), escape(createComponent(Show, {
        get when() {
          return state().options.toolbar.italic;
        },
        get children() {
          return createComponent(Button, {
            onclick: () => formatAs(Markup.Italic),
            get children() {
              return ssr(_tmpl$3, ssrHydrationKey());
            }
          });
        }
      })));
    }
  })), escape(createComponent(Show, {
    get when() {
      return state().options.toolbar.quote || state().options.toolbar.codeBlock || state().options.toolbar.code;
    },
    get children() {
      return ssr(_tmpl$4, ssrHydrationKey(), escape(createComponent(Show, {
        get when() {
          return state().options.toolbar.quote;
        },
        get children() {
          return createComponent(Button, {
            onclick: () => formatAs(Markup.Quote),
            get children() {
              return ssr(_tmpl$5, ssrHydrationKey());
            }
          });
        }
      })), escape(createComponent(Show, {
        get when() {
          return state().options.toolbar.codeBlock;
        },
        get children() {
          return createComponent(Button, {
            onclick: () => formatAs(Markup.CodeBlock),
            get children() {
              return ssr(_tmpl$6, ssrHydrationKey());
            }
          });
        }
      })), escape(createComponent(Show, {
        get when() {
          return state().options.toolbar.code;
        },
        get children() {
          return createComponent(Button, {
            onclick: () => formatAs(Markup.Code),
            get children() {
              return ssr(_tmpl$7, ssrHydrationKey());
            }
          });
        }
      })));
    }
  })), escape(createComponent(Show, {
    get when() {
      return state().options.toolbar.list || state().options.toolbar.orderedList || state().options.toolbar.taskList;
    },
    get children() {
      return ssr(_tmpl$4, ssrHydrationKey(), escape(createComponent(Show, {
        get when() {
          return state().options.toolbar.list;
        },
        get children() {
          return createComponent(Button, {
            onclick: () => formatAs(Markup.List),
            get children() {
              return ssr(_tmpl$8, ssrHydrationKey());
            }
          });
        }
      })), escape(createComponent(Show, {
        get when() {
          return state().options.toolbar.orderedList;
        },
        get children() {
          return createComponent(Button, {
            onclick: () => formatAs(Markup.OrderedList),
            get children() {
              return ssr(_tmpl$9, ssrHydrationKey());
            }
          });
        }
      })), escape(createComponent(Show, {
        get when() {
          return state().options.toolbar.taskList;
        },
        get children() {
          return createComponent(Button, {
            onclick: () => formatAs(Markup.TaskList),
            get children() {
              return ssr(_tmpl$10, ssrHydrationKey());
            }
          });
        }
      })));
    }
  })), escape(createComponent(Show, {
    get when() {
      return state().options.toolbar.link || state().options.toolbar.image || state().options.toolbar.upload;
    },
    get children() {
      return ssr(_tmpl$4, ssrHydrationKey(), escape(createComponent(Show, {
        get when() {
          return state().options.toolbar.link;
        },
        get children() {
          return createComponent(Button, {
            onclick: () => formatAs(Markup.Link),
            get children() {
              return ssr(_tmpl$11, ssrHydrationKey());
            }
          });
        }
      })), escape(createComponent(Show, {
        get when() {
          return state().options.toolbar.image;
        },
        get children() {
          return createComponent(Button, {
            onclick: () => formatAs(Markup.Image),
            get children() {
              return ssr(_tmpl$12, ssrHydrationKey());
            }
          });
        }
      })), escape(createComponent(Show, {
        get when() {
          return state().options.toolbar.upload;
        },
        get children() {
          return createComponent(Button, {
            onclick: uploadClickHandler,
            get children() {
              return [ssr(_tmpl$13, ssrHydrationKey()), ssr(_tmpl$14, ssrHydrationKey(), "display:" + "none")];
            }
          });
        }
      })));
    }
  })));
};

const styles = ".ink-mde {\n  border: 2px solid var(--ink-internal-block-background-color);\n  border-radius: var(--ink-internal-border-radius);\n  color: var(--ink-internal-color, inherit);\n  display: flex;\n  flex-direction: var(--ink-internal-flex-direction, column);\n  font-family: var(--ink-internal-font-family);\n}\n\n.ink-mde .cm-cursor {\n  border-left-color: var(--ink-internal-color, inherit);\n  margin-left: 0;\n}\n\n.ink-mde .cm-tooltip {\n  background-color: var(--ink-internal-block-background-color);\n  border-radius: var(--ink-internal-border-radius);\n  font-family: inherit;\n  padding: 0.25rem;\n}\n\n.ink-mde .cm-tooltip.cm-tooltip-autocomplete ul {\n  font-family: inherit;\n}\n\n.ink-mde .cm-tooltip.cm-tooltip-autocomplete ul li.ink-tooltip-option {\n  border-radius: var(--ink-internal-border-radius);\n  padding: 0.25rem;\n}\n\n.ink-mde .cm-tooltip.cm-tooltip-autocomplete ul li.ink-tooltip-option[aria-selected] {\n  background-color: rgba(150, 150, 150, 0.25);\n}\n\n.ink-mde .cm-completionLabel {\n  font-family: inherit;\n}\n\n.ink-mde, .ink-mde * {\n  box-sizing: border-box;\n}\n\n.ink-mde,\n.ink-mde .ink-mde-editor {\n  display: flex;\n  flex-direction: column;\n  flex-grow: 1;\n  flex-shrink: 1;\n  min-height: 0;\n}\n\n.ink-mde .ink-mde-editor {\n  overflow: auto;\n  padding: 0.5rem;\n}\n\n.ink-mde .ink-mde-toolbar,\n.ink-mde .ink-mde-details {\n  display: flex;\n  flex-grow: 0;\n  flex-shrink: 0;\n}\n\n.ink-mde .ink-mde-details {\n  background-color: var(--ink-internal-block-background-color);\n  display: flex;\n  padding: 0.5rem;\n}\n\n.ink-mde .ink-mde-details-content {\n  color: inherit;\n  display: flex;\n  filter: brightness(0.75);\n  flex-wrap: wrap;\n  font-size: 0.75em;\n  justify-content: flex-end;\n}\n\n.ink-mde .ink-mde-attribution {\n  display: flex;\n  justify-content: flex-end;\n}\n\n.ink-mde .ink-mde-attribution-link {\n  color: currentColor;\n  font-weight: 600;\n  text-decoration: none;\n}\n\n.ink-mde .ink-mde-container {\n  margin-left: auto;\n  margin-right: auto;\n  width: 100%;\n}\n\n.ink-mde .ink-mde-search-panel {\n  background-color: var(--ink-internal-block-background-color);\n  border-radius: 0.25rem;\n  padding: 0.25rem;\n  position: absolute;\n  right: 0.25rem;\n  top: 0.25rem;\n  width: clamp(10rem, 30%, 100%);\n}\n\n.ink-mde .ink-mde-search-panel:focus-within {\n  outline-color: cornflowerblue;\n  outline-style: solid;\n}\n\n.ink-mde .ink-mde-search-input {\n  background-color: transparent;\n  border: none;\n  border-radius: 0.25rem;\n  color: inherit;\n  font-size: inherit;\n  outline: none;\n  width: 100%;\n}\n\n.ink-mde .cm-editor {\n  display: flex;\n  flex-direction: column;\n  position: relative;\n}\n\n.ink-mde .cm-panels {\n  background-color: unset;\n  border: unset;\n  z-index: 10;\n}\n\n.ink-mde .cm-searchMatch {\n  background-color: #6495ed50;\n}\n\n.ink-mde .cm-searchMatch-selected {\n  background-color: #6495edcc;\n}\n\n.ink-mde .cm-scroller {\n  align-items: flex-start;\n  display: flex;\n  font-family: var(--ink-internal-font-family);\n  font-size: var(--ink-internal-editor-font-size);\n  line-height: var(--ink-internal-editor-line-height);\n  overflow-x: auto;\n  position: relative;\n}\n\n.ink-mde .cm-content {\n  display: block;\n  flex-grow: 2;\n  flex-shrink: 0;\n  margin: 0;\n  outline: none;\n  padding: 0;\n  white-space: nowrap;\n}\n\n.ink-mde .cm-lineWrapping {\n  display: flex;\n  flex-direction: column;\n  flex-shrink: 1;\n  overflow-wrap: unset;\n  word-break: break-word;\n  white-space: pre-wrap;\n  width: 100%;\n  overflow-x: hidden;\n}\n\n/* Things that should always break on any char */\n.ink-mde .cm-line .cm-code,\n.ink-mde .cm-line .cm-blockquote {\n  word-break: break-all;\n}\n\n.ink-mde .cm-line {\n  font-family: var(--ink-internal-font-family);\n  padding: 0;\n}\n\n.ink-mde .cm-line span {\n  display: inline;\n}\n\n.ink-mde .cm-line.cm-blockquote {\n  background-color: var(--ink-internal-block-background-color);\n  border-left: 0.25rem solid currentColor;\n  padding: 0 var(--ink-internal-block-padding);\n}\n\n.ink-mde .cm-line.cm-blockquote.cm-blockquote-open {\n  border-top-left-radius: var(--ink-internal-border-radius);\n  border-top-right-radius: var(--ink-internal-border-radius);\n  padding-top: var(--ink-internal-block-padding);\n}\n\n.ink-mde .cm-line.cm-blockquote.cm-blockquote-close {\n  border-bottom-left-radius: var(--ink-internal-border-radius);\n  border-bottom-right-radius: var(--ink-internal-border-radius);\n  padding-bottom: var(--ink-internal-block-padding);\n}\n\n.ink-mde .cm-line.cm-codeblock {\n  background-color: var(--ink-internal-block-background-color);\n  font-family: var(--ink-internal-code-font-family);\n  padding: 0 var(--ink-internal-block-padding);\n}\n\n.ink-mde .cm-line.cm-codeblock.cm-codeblock-open {\n  border-radius: var(--ink-internal-border-radius) var(--ink-internal-border-radius) 0 0;\n  padding-top: var(--ink-internal-block-padding);\n}\n\n.ink-mde .cm-line.cm-codeblock.cm-codeblock-close {\n  border-radius: 0 0 var(--ink-internal-border-radius) var(--ink-internal-border-radius);\n  padding-bottom: var(--ink-internal-block-padding);\n}\n\n.ink-mde .cm-line .cm-code {\n  background-color: var(--ink-internal-block-background-color);\n  font-family: var(--ink-internal-code-font-family);\n  padding: var(--ink-internal-inline-padding) 0;\n}\n\n.ink-mde .cm-line .cm-code.cm-code-open {\n  border-radius: var(--ink-internal-border-radius) 0 0 var(--ink-internal-border-radius);\n  padding-left: var(--ink-internal-inline-padding);\n}\n\n.ink-mde .cm-line .cm-code.cm-code-close {\n  border-radius: 0 var(--ink-internal-border-radius) var(--ink-internal-border-radius) 0;\n  padding-right: var(--ink-internal-inline-padding);\n}\n\n.ink-mde .cm-image-backdrop {\n  background-color: var(--ink-internal-block-background-color);\n}\n\n.ink-mde .ink-mde-block-widget-container {\n  padding: 0.5rem 0;\n}\n\n.ink-mde .ink-mde-block-widget {\n  background-color: var(--ink-internal-block-background-color);\n  border-radius: var(--ink-internal-border-radius);\n  padding: var(--ink-internal-block-padding);\n}\n";

var _tmpl$$2 = ["<style", ">", "</style>"];
const Styles = () => {
  const [state, setState] = useStore();
  const [vars, setVars] = createSignal(makeVars(state()));
  createEffect(() => {
    setVars(makeVars(state()));
  });
  onMount(() => {
    const mediaQueryList = window.matchMedia('(prefers-color-scheme: dark)');
    const listener = _event => {
      const {
        editor,
        root,
        workQueue
      } = state();
      if (root.isConnected) {
        workQueue.enqueue(async () => {
          const effects = await buildVendorUpdates([state, setState]);
          editor.dispatch({
            effects
          });
          setVars(makeVars(state()));
        });
      } else {
        mediaQueryList.removeEventListener('change', listener);
      }
    };
    mediaQueryList.addEventListener('change', listener);
  });
  return ssr(_tmpl$$2, ssrHydrationKey(), `.ink {\n  ${vars().join('\n  ')}\n}\n${styles}` || " ");
};

var _tmpl$$1 = ["<div class=\"ink-mde-editor\">", "</div>"];
const Root = props => {
  const [state, setState] = useStore();
  return ssrElement("div", mergeProps({
    "class": 'ink ink-mde'
  }, getHydrationMarkerProps), () => ["<!--$-->", escape(createComponent(Styles, {})), "<!--/-->", "<!--$-->", escape(createComponent(Show, {
    get when() {
      return state().options.files.clipboard || state().options.files.dragAndDrop;
    },
    get children() {
      return createComponent(DropZone, {});
    }
  })), "<!--/-->", "<!--$-->", escape(createComponent(Show, {
    get when() {
      return state().options.interface.toolbar;
    },
    get children() {
      return createComponent(Toolbar, {});
    }
  })), "<!--/-->", ssr(_tmpl$$1, escape(createComponent(Editor, {
    get target() {
      return props.target;
    }
  }))), "<!--$-->", escape(createComponent(Show, {
    get when() {
      return state().options.readability || state().options.interface.attribution;
    },
    get children() {
      return createComponent(Details, {
        store: [state, setState]
      });
    }
  })), "<!--/-->"], true);
};

const AppContext = createContext([() => blankState(), value => typeof value === 'function' ? value(blankState()) : value]);
const AppProvider = props => {
  return (// eslint-disable-next-line solid/reactivity
    createComponent(AppContext.Provider, {
      get value() {
        return props.store;
      },
      get children() {
        return props.children;
      }
    })
  );
};
const useStore = () => {
  return useContext(AppContext);
};
const App = props => {
  return createComponent(AppProvider, {
    get store() {
      return props.store;
    },
    get children() {
      return createComponent(Root, {
        get store() {
          return props.store;
        },
        get target() {
          return props.target;
        }
      });
    }
  });
};

var _tmpl$ = ["<div", ' class="ink-mde-textarea"></div>'];
const defineConfig = (config) => config;
const defineOptions = (options) => options;
const definePlugin = (plugin2) => plugin2;
const hydrate = (target, options = {}) => {
  const store = makeStore(options);
  return makeInstance(store);
};
const ink = (target, options = {}) => {
  const hasHydrationMarker = !!target.querySelector(HYDRATION_MARKER_SELECTOR);
  if (hasHydrationMarker) {
    return hydrate(target, options);
  }
  return render(target, options);
};
const inkPlugin = ({
  key = "",
  type,
  value
}) => {
  return new Proxy({
    key,
    type: type || "default"
  }, {
    get: (target, prop, _receiver) => {
      if (prop === "value" && !target[prop]) {
        target.value = value();
        if (isPromise(target.value)) {
          return target.value.then((val) => target.value = val);
        }
        return target.value;
      }
      return target[prop];
    }
  });
};
const plugin = inkPlugin;
const render = (target, options = {}) => {
  const store = makeStore(options);
  return makeInstance(store);
};
const renderToString = (options = {}) => {
  const store = makeStore(options);
  return renderToString$1(() => createComponent(App, {
    store
  }));
};
const solidPrepareForHydration = () => {
  let e, t;
  e = window._$HY || (window._$HY = {
    events: [],
    completed: /* @__PURE__ */ new WeakSet(),
    r: {}
  }), t = (e2) => e2 && e2.hasAttribute && (e2.hasAttribute("data-hk") ? e2 : t(e2.host && e2.host instanceof Node ? e2.host : e2.parentNode)), ["click", "input"].forEach((o) => document.addEventListener(o, (o2) => {
    let s = o2.composedPath && o2.composedPath()[0] || o2.target, a = t(s);
    a && !e.completed.has(a) && e.events.push([a, o2]);
  })), e.init = (t2, o) => {
    e.r[t2] = [new Promise((e2, t3) => o = e2), o];
  }, e.set = (t2, o, s) => {
    (s = e.r[t2]) && s[1](o), e.r[t2] = [o];
  }, e.unset = (t2) => {
    delete e.r[t2];
  }, e.load = (t2, o) => {
    if (o = e.r[t2])
      return o[0];
  };
};
const wrap = (textarea, options = {}) => {
  const replacement = ssr(_tmpl$, ssrHydrationKey());
  const doc = textarea.value;
  textarea.after(replacement);
  textarea.style.display = "none";
  const instance = render(replacement, {
    doc,
    ...options
  });
  if (textarea.form) {
    textarea.form.addEventListener("submit", () => {
      textarea.value = instance.getDoc();
    });
  }
  return instance;
};

export { appearanceTypes, buildWidget as b, ink as default, defineConfig, defineOptions, definePlugin, filterPlugins as f, hydrate, ink, inkPlugin, partitionPlugins as p, plugin, pluginTypes, render, renderToString, solidPrepareForHydration, wrap };
//# sourceMappingURL=index.js.map
