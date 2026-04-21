import { Injectable } from '@angular/core';
import { Observable, of } from 'rxjs';

import { Platform } from './platform-data';
import platformData from '../../../generated/platform.json';

@Injectable({
  providedIn: 'root'
})
export class PlatformService {
  public getAllPlatforms(): Observable<Platform[]> {
    return of(platformData as Platform[]);
  }
}
