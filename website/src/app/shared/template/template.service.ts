import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { PlatformType, Template } from 'app/core';
import { Observable, map, shareReplay, take, tap } from 'rxjs';

interface GeneratedTemplateData {
  templates: Template[];
}

@Injectable({
  providedIn: 'root'
})
export class TemplateService {
  constructor(
    private http: HttpClient
  ) { }

  private data$: Observable<GeneratedTemplateData> | null = null;

  public filterTemplatesByPlatformType(
    platformType: PlatformType | 'all'
  ): Observable<Template[]> {
    return this.retrieveData()
      .pipe(
        map(data =>
          platformType === 'all'
            ? data.templates
            : data.templates.filter((template: Template) => template.platformType === platformType)
        )
      );
  }

  public retrieveData(): Observable<GeneratedTemplateData> {
    if (!this.data$) {
      this.data$ = this.http.get<GeneratedTemplateData>('/assets/templates.json')
        .pipe(
          take(1),
          shareReplay(1)
        );
    }

    return this.data$;
  }
}
