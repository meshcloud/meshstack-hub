import { Injectable } from '@angular/core';
import { Meta, Title } from '@angular/platform-browser';

const SITE_NAME = 'meshStack Hub';

@Injectable({ providedIn: 'root' })
export class SeoService {
  constructor(private title: Title, private meta: Meta) {}

  public setDefault(): void {
    this.set(
      `${SITE_NAME} — Terraform Module Registry`,
      'Browse and import Terraform building blocks for meshStack integrations across Azure, AWS, GCP, STACKIT, and more.'
    );
  }

  public set(title: string, description: string): void {
    const fullTitle = title.includes(SITE_NAME) ? title : `${title} | ${SITE_NAME}`;
    this.title.setTitle(fullTitle);
    this.meta.updateTag({ name: 'description', content: description });
    this.meta.updateTag({ property: 'og:title', content: fullTitle });
    this.meta.updateTag({ property: 'og:description', content: description });
  }
}

