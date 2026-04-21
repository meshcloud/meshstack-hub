import { Injectable } from '@angular/core';
import { Observable, map, of } from 'rxjs';

import { ReferenceArchitecture } from 'app/core';
import refArchData from '../../../generated/reference-architectures.json';

interface GeneratedRefArchData {
  referenceArchitectures: ReferenceArchitecture[];
}

@Injectable({
  providedIn: 'root'
})
export class ReferenceArchitectureService {
  private data = refArchData as GeneratedRefArchData;

  public getAll(): Observable<ReferenceArchitecture[]> {
    return of(this.data.referenceArchitectures);
  }

  public getById(id: string): Observable<ReferenceArchitecture> {
    return of(this.data.referenceArchitectures).pipe(
      map(archs => {
        const arch = archs.find(a => a.id === id);

        if (!arch) {
          throw new Error(`Reference architecture with id ${id} not found`);
        }

        return arch;
      })
    );
  }
}

