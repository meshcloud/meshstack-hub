import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable, shareReplay, take } from 'rxjs';

import { Platform } from './platform-data';

@Injectable({
  providedIn: 'root'
})
export class PlatformService {
  constructor(private http: HttpClient) { }

  public getAllPlatforms(): Observable<Platform[]> {
    return this.http.get<Platform[]>('/assets/platform.json')
      .pipe(
        take(1),
        shareReplay(1)
      );
  }
}
