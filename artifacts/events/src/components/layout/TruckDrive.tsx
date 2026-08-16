import React, { useEffect, useRef, useState } from 'react';

export const TRUCK_DRIVE_EVENT = 'truck-drive';

/** Fire this whenever a charge is submitted to send the truck across the header. */
export function triggerTruckDrive() {
  window.dispatchEvent(new CustomEvent(TRUCK_DRIVE_EVENT));
}

/**
 * Animated garbage truck that drives across the header, emerging from under
 * the "Route Events" title and disappearing when it reaches the EN|ES|FR
 * language switcher. Rendered inside the header (which must be relative).
 */
export function TruckDrive({ startRef, endRef }: {
  startRef: React.RefObject<HTMLElement | null>;
  endRef: React.RefObject<HTMLElement | null>;
}) {
  const [run, setRun] = useState(0);
  const [coords, setCoords] = useState<{ from: number; to: number } | null>(null);
  const truckRef = useRef<HTMLImageElement>(null);

  useEffect(() => {
    const handler = () => {
      const start = startRef.current?.getBoundingClientRect();
      const end = endRef.current?.getBoundingClientRect();
      if (!start || !end) return;
      setCoords({ from: start.left, to: end.left });
      setRun(n => n + 1);
    };
    window.addEventListener(TRUCK_DRIVE_EVENT, handler);
    return () => window.removeEventListener(TRUCK_DRIVE_EVENT, handler);
  }, [startRef, endRef]);

  useEffect(() => {
    if (!run || !coords || !truckRef.current) return;
    const el = truckRef.current;
    el.style.display = 'block';
    const distance = coords.to - coords.from - 56; // stop as nose hits the control cluster
    const anim = el.animate(
      [
        { transform: 'translateX(0)', opacity: 0 },
        { transform: 'translateX(24px)', opacity: 1, offset: 0.06 },
        { transform: `translateX(${Math.max(distance - 24, 0)}px)`, opacity: 1, offset: 0.94 },
        { transform: `translateX(${Math.max(distance, 0)}px)`, opacity: 0 },
      ],
      { duration: 9600, easing: 'linear', fill: 'forwards' },
    );
    anim.onfinish = () => { el.style.display = 'none'; };
    return () => anim.cancel();
  }, [run, coords]);

  if (!coords) return null;

  return (
    <img
      ref={truckRef}
      src={`${import.meta.env.BASE_URL}truck.gif`}
      alt=""
      aria-hidden="true"
      className="pointer-events-none fixed z-[100] h-12 w-auto"
      style={{ display: 'none', opacity: 0, left: coords.from, top: 4 }}
    />
  );
}
