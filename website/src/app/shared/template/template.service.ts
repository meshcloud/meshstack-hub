import { Injectable } from '@angular/core';
import { PlatformType, Template } from '../../core';
import { HttpClient } from '@angular/common/http';
import { map, Observable } from 'rxjs';

interface GeneratedData {
  buildingBlocks: Template[];
}

@Injectable({
  providedIn: 'root'
})
export class TemplateService {
  constructor(
    private http: HttpClient
  ) {}

  public filterTemplatesByPlatformType(
    platformType: PlatformType | 'ALL'
  ): Observable<Template[]> {
    return this.generatedData().pipe(
      map(data =>
        platformType === 'ALL'
          ? data.buildingBlocks
          : data.buildingBlocks.filter((template: Template) => template.platformType === platformType)
      )
    );
  }

  public generatedData(): Observable<GeneratedData> {
    return this.http.get<GeneratedData>('/assets/generated.json');
  }
}
