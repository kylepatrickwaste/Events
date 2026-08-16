import { Ban, Biohazard, DoorClosed, DoorOpen, Eye, PackageX, Weight } from 'lucide-react';
import { cn } from '@/lib/utils';

/**
 * Marks used in place of words in the events grid. Every column that spends a
 * lot of width saying the same handful of things gets one of these instead, so
 * more of the row's actual data fits on screen.
 *
 * Each mark carries its label twice: a `title` for the pointer and an sr-only
 * span for assistive tech, so collapsing the text loses nothing but the width.
 */

/** Wraps a mark so every column lines up on the same 16px box. */
function Glyph({ label, className, children }: { label: string; className?: string; children: React.ReactNode }) {
  return (
    <span title={label} className={cn('inline-flex h-4 w-4 items-center justify-center align-middle', className)}>
      {children}
      <span className="sr-only">{label}</span>
    </span>
  );
}

/** A vendor mark built from a letter: a filled tile with the initial on it. */
function LetterMark({ letter, label, className }: { letter: string; label: string; className: string }) {
  return (
    <span
      title={label}
      className={cn(
        'inline-flex h-4 w-4 items-center justify-center rounded-[3px] align-middle text-[9px] font-bold leading-none text-white',
        className
      )}
    >
      {letter}
      <span className="sr-only">{label}</span>
    </span>
  );
}

/**
 * A bin whose lid has been pushed askew by rubbish piled over the rim, which is
 * precisely what an "Extra" is: more waste than the container holds.
 */
export function OverflowingBin({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      aria-hidden="true"
    >
      {/* Rubbish heaped over the rim. Filled, and only two of them: at 16px
          three outlined circles collapse into a smudge. */}
      <circle cx="9" cy="6.9" r="2.1" fill="currentColor" stroke="none" />
      <circle cx="14.7" cy="5.5" r="2.6" fill="currentColor" stroke="none" />
      {/* the lid, shoved crooked by the pile */}
      <path d="M3.5 11.7 L20.5 9.7" />
      {/* the bin */}
      <path d="M5.9 13.5 L7.1 21.4 h9.8 L18.1 13.5" />
    </svg>
  );
}

/** Open events get a green open door, closed ones a red shut door. */
export function EventStatusGlyph({ open, openLabel, closedLabel }: {
  open: boolean;
  openLabel: string;
  closedLabel: string;
}) {
  return open ? (
    <Glyph label={openLabel}>
      <DoorOpen className="h-4 w-4 text-green-600 dark:text-green-500" />
    </Glyph>
  ) : (
    <Glyph label={closedLabel}>
      <DoorClosed className="h-4 w-4 text-red-600 dark:text-red-500" />
    </Glyph>
  );
}

/**
 * One mark per overage type. An unrecognised type falls back to its own name
 * rather than a meaningless placeholder -- a new type in the database should
 * still be readable before anyone draws it a mark.
 */
export function EventTypeGlyph({ name }: { name?: string | null }) {
  const label = (name ?? '').trim();
  switch (label.toLowerCase()) {
    case 'extra':
      return <Glyph label={label}><OverflowingBin className="h-4 w-4 text-amber-600 dark:text-amber-500" /></Glyph>;
    case 'overloaded':
      return <Glyph label={label}><Weight className="h-4 w-4 text-orange-600 dark:text-orange-500" /></Glyph>;
    case 'contamination':
      return <Glyph label={label}><Biohazard className="h-4 w-4 text-rose-600 dark:text-rose-500" /></Glyph>;
    case 'not out':
      return <Glyph label={label}><PackageX className="h-4 w-4 text-slate-500" /></Glyph>;
    case 'blocked container':
      return <Glyph label={label}><Ban className="h-4 w-4 text-violet-600 dark:text-violet-500" /></Glyph>;
    case '':
      return <span className="text-muted-foreground">—</span>;
    default:
      return <span className="text-xs whitespace-nowrap">{label}</span>;
  }
}

/** One mark per camera vendor. */
export function EventSourceGlyph({ name }: { name?: string | null }) {
  const label = (name ?? '').trim();
  switch (label.toLowerCase()) {
    case '':
      return <span className="text-muted-foreground">—</span>;
    case '3rd eye':
      return <Glyph label={label}><Eye className="h-4 w-4 text-slate-700 dark:text-slate-300" /></Glyph>;
    case 'wastevision':
    case 'waste vision':
      return <LetterMark letter="W" label={label} className="bg-blue-600" />;
    case 'samsara':
      return <LetterMark letter="S" label={label} className="bg-green-600" />;
    default:
      // Anything else still gets a tile, so an unknown vendor reads as a vendor
      // rather than as a missing value.
      return <LetterMark letter={label[0].toUpperCase()} label={label} className="bg-muted-foreground/70" />;
  }
}
