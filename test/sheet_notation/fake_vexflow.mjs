export function createFakeVexFlow() {
  const calls = {
    notes: [],
    annotations: [],
    articulations: [],
    beams: [],
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
    static VerticalJustify = { BOTTOM: 'bottom' };

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
      return this;
    }
  }

  class Beam {
    constructor(notes) {
      this.notes = notes;
      calls.beams.push(this);
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
    Voice,
    Formatter,
    Beam,
    GraceNote,
    GraceNoteGroup,
    Modifier: { Position: { ABOVE: 'above' } },
  };
}
