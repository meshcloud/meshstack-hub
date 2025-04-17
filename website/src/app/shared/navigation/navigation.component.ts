import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { RouterModule } from '@angular/router';
import { Observable, map } from 'rxjs';

import { Card, CardComponent, CardConfig } from 'app/shared/card';

import { PlatformLogoService } from '../platform-logo';

@Component({
  selector: 'mst-navigation',
  imports: [CommonModule, RouterModule, CardComponent],
  templateUrl: './navigation.component.html',
  styleUrl: './navigation.component.scss',
  standalone: true
})
export class NavigationComponent implements OnInit {
  public cards$!: Observable<Card[]>;

  public cardConfig: CardConfig = {
    titleNextToLogo: true,
    showFooter: false,
    borderDominantColorOfLogo: true
  };

  constructor(
    private readonly platformLogoService: PlatformLogoService
  ) { }

  public ngOnInit(): void {
    this.cards$ = this.platformLogoService.getLogoUrls()
      .pipe(
        map((logos) =>
          Object.entries(logos)
            .map(([key, logoUrl]) => {
              switch (key) {
              case 'azure':
                return this.createCard('Azure', logoUrl, '/azure');
              case 'aws':
                return this.createCard('AWS', logoUrl, '/aws');
              case 'gcp':
                return this.createCard('GCP', logoUrl, '/gcp');
              case 'github':
                return this.createCard('GitHub', logoUrl, '/github');
              case 'aks':
                return this.createCard('Azure Kubernetes Service', logoUrl, '/aks');
              default:
                return this.createCard(key, logoUrl, `/${key}`);
              }
            })
        )
      );
  }

  private createCard(title: string, logoUrl: string, routePath: string): Card {
    return {
      cardLogo: logoUrl,
      title,
      description: null,
      routePath: routePath,
      supportedPlatforms: []
    };
  }
}