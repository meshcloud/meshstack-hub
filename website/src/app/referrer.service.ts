import { Injectable } from '@angular/core';

@Injectable({ providedIn: 'root' })
export class ReferrerService {

  public saveMeshstackUrl(url: string) {
    localStorage.setItem('referrerUrl', url);
  }

  public getMeshstackUrl(): string {
    return localStorage.getItem('referrerUrl') ?? '';
  }
}