import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, ReactiveFormsModule } from '@angular/forms';
import { ActivatedRoute } from '@angular/router';
import { Observable, Subscription, forkJoin, map, take } from 'rxjs';

import { PlatformType, Template } from 'app/core';
import { CardComponent } from 'app/shared/card';
import { NavigationComponent } from 'app/shared/navigation';
import { PlatformLogoData, PlatformLogoService } from 'app/shared/platform-logo';
import { TemplateService } from 'app/shared/template';

interface TemplateVm extends Template {
  imageUrl: string | null;
  detailsRoute: string;
}

@Component({
  selector: 'mst-template-gallery',
  imports: [CommonModule, ReactiveFormsModule, CardComponent, NavigationComponent],
  templateUrl: './template-gallery.component.html',
  styleUrl: './template-gallery.component.scss',
  standalone: true
})
export class TemplateGalleryComponent implements OnInit, OnDestroy {

  public templates$!: Observable<TemplateVm[]>;

  public searchForm!: FormGroup;

  private routeSubscription!: Subscription;

  private logos$!: Observable<PlatformLogoData>;

  constructor(
    private route: ActivatedRoute,
    private fb: FormBuilder,
    private templateService: TemplateService,
    private platformLogoService: PlatformLogoService
  ) { }


  public ngOnInit(): void {
    this.searchForm = this.fb.group({
      searchTerm: ['']
    });

    this.routeSubscription = this.route.paramMap.subscribe(params => {
      const type = params.get('type') as PlatformType ?? 'all';
      this.logos$ = this.platformLogoService.getLogoUrls();
      this.templates$ = forkJoin({
        templates: this.templateService.filterTemplatesByPlatformType(type),
        logos: this.logos$
      })
        .pipe(
          map(({ templates, logos }) =>
            templates.map(item => ({
              ...item,
              imageUrl: logos[item.platformType] ?? null,
              detailsRoute: `/template/${item.id}`
            }))
          )
        );
    });
  }

  public ngOnDestroy(): void {
    this.routeSubscription.unsubscribe();
  }

  public onSearch(): void {
    const search = this.searchForm.value.searchTerm;

    this.templates$ = forkJoin({
      templates: this.templateService.search(search),
      logos: this.logos$
    })
      .pipe(
        map(({ templates, logos }) =>
          templates.map(item => ({
            ...item,
            imageUrl: logos[item.platformType] ?? null,
            detailsRoute: `/template/${item.id}`
          }))
        )
      );
  }
}
