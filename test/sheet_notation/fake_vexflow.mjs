export function createFakeVexFlow() {
  const calls = {
    notes: [],
    annotations: [],
    articulations: [],
    beams: [],
    events: [],
    parentheses: [],
    voices: [],
    staves: [],
  };

  class Renderer {
    static Backends = { SVG: 'svg' };

    constructor(host, backend) {
      this.host = host;
      this.backend = backend;
      this.svg = { tagName: 'svg', outerHTML: '<svg data-fake-vexflow="true"></svg>' };
      host.appendChild(this.svg);
    }

    resize(width, height) {
      this.width = width;
      this.height = height;
      this.svg.outerHTML = `<svg data-fake-vexflow="true" width="${width}" height="${height}"></svg>`;
    }

    getContext() {
      return { renderer: this };
    }
  }

  class Stave {
    constructor(x, y, width) {
      this.x = x;
      this.y = y;
      this.width = width;
      calls.staves.push(this);
    }

    addClef(clef) {
      this.clef = clef;
      return this;
    }

    addTimeSignature(timeSignature) {
      this.timeSignature = timeSignature;
      return this;
    }

    setEndBarType(type) {
      this.endBarType = type;
      return this;
    }

    setContext(context) {
      this.context = context;
      return this;
    }

    draw() {
      this.drawn = true;
      return this;
    }
  }

  class StaveNote {
    constructor(options) {
      this.options = options;
      this.modifiers = [];
      this.keyStyles = [];
      calls.notes.push(this);
    }

    addModifier(modifier, index) {
      this.modifiers.push({ modifier, index });
      return this;
    }

    setKeyStyle(index, style) {
      this.keyStyles[index] = style;
      return this;
    }
  }

  class Annotation {
    static VerticalJustify = { BOTTOM: 'bottom', TOP: 'top' };

    constructor(text) {
      this.text = text;
      calls.annotations.push(this);
    }

    setFont(family, size, weight) {
      this.font = { family, size, weight };
      return this;
    }

    setVerticalJustification(value) {
      this.verticalJustification = value;
      return this;
    }
  }

  class Articulation {
    constructor(type) {
      this.type = type;
      calls.articulations.push(this);
    }

    setPosition(position) {
      this.position = position;
      return this;
    }
  }

  class Parenthesis {
    constructor(position) {
      this.position = position;
      calls.parentheses.push(this);
    }
  }

  class Voice {
    constructor(options) {
      this.options = options;
      this.tickables = [];
      calls.voices.push(this);
    }

    setStrict(value) {
      this.strict = value;
      return this;
    }

    addTickables(notes) {
      this.tickables.push(...notes);
      return this;
    }

    draw(context, stave) {
      calls.events.push('voice:draw');
      this.context = context;
      this.stave = stave;
    }
  }

  class Formatter {
    joinVoices(voices) {
      this.voices = voices;
      return this;
    }

    format(voices, width) {
      this.formatWidth = width;
      voices.forEach((voice) => {
        voice.formatterWidth = width;
      });
      return this;
    }
  }

  class Beam {
    constructor(notes) {
      this.notes = notes;
      this.render_options = { flat_beams: false };
      for (const note of notes) {
        note.beam = this;
      }
      calls.events.push('beam:create');
      calls.beams.push(this);
    }

    setContext(context) {
      this.context = context;
      return this;
    }

    draw() {
      calls.events.push('beam:draw');
      this.drawn = true;
      return this;
    }
  }

  class GraceNote {
    constructor(options) {
      this.options = options;
    }
  }

  class GraceNoteGroup {
    constructor(notes, slur) {
      this.notes = notes;
      this.slur = slur;
    }

    beamNotes() {
      this.beamed = true;
      return this;
    }

    attach(note) {
      note.graceNoteGroup = this;
      return this;
    }
  }

  return {
    calls,
    Renderer,
    Stave,
    StaveNote,
    Annotation,
    Articulation,
    Parenthesis,
    Voice,
    Formatter,
    Beam,
    GraceNote,
    GraceNoteGroup,
    BarlineType: { REPEAT_END: 5 },
    Modifier: { Position: { ABOVE: 'above', LEFT: 'left', RIGHT: 'right' } },
  };
}
