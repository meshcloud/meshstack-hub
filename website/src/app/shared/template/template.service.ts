import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable, map, shareReplay, take } from 'rxjs';

import { PlatformType, Template } from 'app/core';

interface GeneratedTemplateData {
  templates: Template[];
}

@Injectable({
  providedIn: 'root'
})
export class TemplateService {
  private data$: Observable<GeneratedTemplateData> | null = null;

  constructor(
    private http: HttpClient
  ) { }

  public search(
    term: string
  ): Observable<Template[]> {
    return this.retrieveData()
      .pipe(
        map(data =>
          data.templates.filter((template: Template) =>
            template.name.toLowerCase()
              .includes(term.toLowerCase()) ||
            template.description.toLowerCase()
              .includes(term.toLowerCase())
          )
        )
      );
  }

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

  public getTemplateById(
    id: string
  ): Observable<Template> {
    return this.retrieveData()
      .pipe(
        map(data => {
          const template = data.templates.find((t: Template) => t.id === id);

          if (!template) {
            throw new Error(`Template with id ${id} not found`);
          }

          return template;
        })
      );
  }

  public retrieveData(): Observable<GeneratedTemplateData> {
    if (!this.data$) {
      this.data$ = this.http.get<GeneratedTemplateData>('/assets/templates.json')
        .pipe(
          take(1)
        );
    }

    return this.data$;
  }
}
