import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, ReactiveFormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { Observable, Subscription, forkJoin, map, tap } from 'rxjs';

import { PlatformType } from 'app/core';
import { CardComponent } from 'app/shared/card';
import { Card } from 'app/shared/card/card';
import { NavigationComponent } from 'app/shared/navigation';
import { PlatformLogoData, PlatformLogoService } from 'app/shared/platform-logo';
import { TemplateService } from 'app/shared/template';

@Component({
  selector: 'mst-template-gallery',
  imports: [CommonModule, ReactiveFormsModule, CardComponent, NavigationComponent],
  templateUrl: './template-gallery.component.html',
  styleUrl: './template-gallery.component.scss',
  standalone: true
})
export class TemplateGalleryComponent implements OnInit, OnDestroy {

  public templates$!: Observable<Card[]>;

  public searchForm!: FormGroup;

  public isSearch = false;

  private paramSubscription!: Subscription;

  private logos$!: Observable<PlatformLogoData>;

  constructor(
    private router: Router,
    private route: ActivatedRoute,
    private fb: FormBuilder,
    private templateService: TemplateService,
    private platformLogoService: PlatformLogoService
  ) { }

  public ngOnInit(): void {
    this.searchForm = this.fb.group({
      searchTerm: ['']
    });

    this.paramSubscription = this.route.paramMap.subscribe(params => {
      const type = params.get('type') ?? 'all';

      const templateObs$ = this.templateService.filterTemplatesByPlatformType(type as PlatformType);
      this.logos$ = this.platformLogoService.getLogoUrls();
      this.templates$ = forkJoin({
        templates: templateObs$,
        logos: this.logos$
      })
        .pipe(
          tap(() => this.isSearch = false),
          map(({ templates, logos }) => templates.map(item => ({
            cardLogo: item.logo,
            title: item.name,
            description: item.description,
            detailsRoute: `/template/${item.id}`,
            supportedPlatforms: item.supportedPlatforms.map(platform => ({ platformType: platform, imageUrl: logos[item.platformType] ?? null }))
          }))
          ),

        );
    });
  }

  public ngOnDestroy(): void {
    this.paramSubscription.unsubscribe();
  }

  public onSearch(): void {
    const searchTerm = this.searchForm.value.searchTerm;
    this.templates$ = forkJoin({
      templates: this.templateService.search(searchTerm),
      logos: this.logos$
    })
      .pipe(
        tap(() => {
          this.isSearch = !!searchTerm
        }),
        map(({ templates, logos }) => templates.map(item => ({
          cardLogo: item.logo,
          title: item.name,
          description: item.description,
          detailsRoute: `/template/${item.id}`,
          supportedPlatforms: item.supportedPlatforms.map(platform => ({ platformType: platform, imageUrl: logos[item.platformType] ?? null }))
        }))
        )
      );

    this.router.navigate(
      ['/all']
    );
  }
}
