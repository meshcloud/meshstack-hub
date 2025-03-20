import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable, map, shareReplay, take } from 'rxjs';

import { PlatformLogoData } from './platform-logo-data';

@Injectable({
  providedIn: 'root'
})
export class PlatformLogoService {
  private logoDataCache$: Observable<PlatformLogoData> | null = null;

  constructor(private http: HttpClient) { }


  public getLogoUrls(): Observable<PlatformLogoData> {
    if (!this.logoDataCache$) {
      this.logoDataCache$ = this.http.get<PlatformLogoData>('/assets/platform-logos.json')
        .pipe(
          take(1),
          shareReplay(1)
        );
    }

    return this.logoDataCache$;
  }
}
