import ColorThief from 'colorthief';
import { Observable } from 'rxjs';

/**
 * Extracts the dominant color from an image URL using ColorThief and returns an rgba string with the given alpha.
 * @param imageUrl The image URL
 * @param alpha The alpha value for the rgba color (default 0.1)
 * @returns Observable<string | null> The rgba color string or null if extraction fails
 */
export function extractLogoColor(imageUrl: string, alpha = 0.1): Observable<string | null> {
  return new Observable<string | null>((observer) => {
    if (!imageUrl || typeof window === 'undefined') {
      observer.next(null);
      observer.complete();
      return;
    }
    const img = new Image();
    img.crossOrigin = 'Anonymous';
    img.src = imageUrl;
    img.onload = () => {
      try {
        const colorThief = new ColorThief();
        const dominantColor = colorThief.getColor(img);
        observer.next(`rgba(${dominantColor.join(',')}, ${alpha})`);
      } catch {
        observer.next(null);
      }
      observer.complete();
    };
    img.onerror = () => {
      observer.next(null);
      observer.complete();
    };
  });
}
