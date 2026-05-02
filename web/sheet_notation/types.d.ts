export type DrumNotationDocument = {
  timeSignature: string;
  measures: DrumNotationMeasure[];
};

export type DrumNotationMeasure = {
  notes: DrumNotationNote[];
};

export type DrumNotationNote = {
  value: DrumNoteValue;
  voices?: DrumVoiceId[];
  rest?: boolean;
  sticking?: string;
  accent?: boolean;
  flam?: boolean;
  ghost?: boolean;
  tie?: boolean;
};

export type DrumNotationRenderOptions = {
  baseMeasureWidth?: number;
  measureWidth?: number;
  staffX?: number;
  staffY?: number;
  staffHeight?: number;
  paddingRight?: number;
  formatterWidth?: number;
  formatterWidthScale?: number;
  availableWidth?: number;
  notesPerSystem?: number | "auto";
  minNoteWidth?: number;
  systemEndReserve?: number;
  systemGapY?: number;
  repeatClefEverySystem?: boolean;
  repeatTimeSignatureEverySystem?: boolean;
  stemMode?: "single" | "mapped";
  flatBeams?: boolean;
  flatBeamOffset?: number;
};

export type DrumNoteValue = "1n" | "2n" | "4n" | "8n" | "16n" | "32n";

export type DrumVoiceId =
  | "hihat"
  | "ride"
  | "crash"
  | "snare"
  | "tom1"
  | "tom2"
  | "floorTom"
  | "kick";

export function parseDrumNotationDocument(input: unknown): DrumNotationDocument;
export function renderDrumNotationSvg(
  document: DrumNotationDocument | string,
  options?: DrumNotationRenderOptions,
): string;
