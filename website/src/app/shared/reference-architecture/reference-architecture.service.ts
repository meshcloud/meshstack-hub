import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable, map, take } from 'rxjs';

import { ReferenceArchitecture } from 'app/core';

interface GeneratedRefArchData {
  referenceArchitectures: ReferenceArchitecture[];
}

@Injectable({
  providedIn: 'root'
})
export class ReferenceArchitectureService {
  private data$: Observable<GeneratedRefArchData> | null = null;

  constructor(private http: HttpClient) {}

  public getAll(): Observable<ReferenceArchitecture[]> {
    return this.retrieveData()
      .pipe(map(data => data.referenceArchitectures));
  }

  public getById(id: string): Observable<ReferenceArchitecture> {
    return this.retrieveData()
      .pipe(
        map(data => {
          const arch = data.referenceArchitectures.find(a => a.id === id);

          if (!arch) {
            throw new Error(`Reference architecture with id ${id} not found`);
          }

          return arch;
        })
      );
  }

  private retrieveData(): Observable<GeneratedRefArchData> {
    if (!this.data$) {
      this.data$ = this.http.get<GeneratedRefArchData>('/assets/reference-architectures.json')
        .pipe(take(1));
    }

    return this.data$;
  }
}

