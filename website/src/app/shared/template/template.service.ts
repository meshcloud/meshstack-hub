import { Injectable } from '@angular/core';
import { Observable, map, of } from 'rxjs';

import { Template } from 'app/core';
import templatesData from '../../../generated/templates.json';

interface GeneratedTemplateData {
  templates: Template[];
}

@Injectable({
  providedIn: 'root'
})
export class TemplateService {
  private data = templatesData as unknown as GeneratedTemplateData;

  public search(
    term: string
  ): Observable<Template[]> {
    return of(this.data.templates).pipe(
      map(templates =>
        templates.filter((template: Template) =>
          template.name.toLowerCase()
            .includes(term.toLowerCase()) ||
          template.description.toLowerCase()
            .includes(term.toLowerCase())
        )
      )
    );
  }

  public filterTemplatesByPlatformType(
    platformType: string | 'all'
  ): Observable<Template[]> {
    return of(this.data.templates).pipe(
      map(templates =>
        platformType === 'all'
          ? templates
          : templates.filter((template: Template) => template.platformType === platformType)
      )
    );
  }

  public getTemplateById(
    id: string
  ): Observable<Template> {
    return of(this.data.templates).pipe(
      map(templates => {
        const template = templates.find((t: Template) => t.id === id);

        if (!template) {
          throw new Error(`Template with id ${id} not found`);
        }

        return template;
      })
    );
  }

  public retrieveData(): Observable<GeneratedTemplateData> {
    return of(this.data);
  }
}
