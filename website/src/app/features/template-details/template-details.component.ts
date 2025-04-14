import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import { Observable, Subscription, map } from 'rxjs';

import { PlatformType } from 'app/core';
import { TemplateService } from 'app/shared/template';

import { ImportDialogComponent } from './import-dialog/import-dialog.component';

interface TemplateDetailsVm {
  imageUrl: string | null;
  name: string;
  platformType: PlatformType;
  description: string;
  howToUse: string;
  source: string;
}

@Component({
  selector: 'mst-template-details',
  imports: [CommonModule],
  templateUrl: './template-details.component.html',
  styleUrl: './template-details.component.scss',
  standalone: true

})
export class TemplateDetailsComponent implements OnInit, OnDestroy {
  public template$!: Observable<TemplateDetailsVm>;

  public copyLabel = 'Copy';

  private routeSubscription!: Subscription;

  constructor(
    private route: ActivatedRoute,
    private templateService: TemplateService,
    private modalService: NgbModal
  ) { }

  public ngOnInit(): void {
    this.routeSubscription = this.route.paramMap.subscribe(params => {
      const id = params.get('id');

      if (!id) {
        throw new Error('Template ID is required');
      }

      this.template$ = this.templateService.getTemplateById(id)
        .pipe(
          map((template) => ({
            ...template,
            imageUrl: template.logo,
            source: template.githubUrls.https,
            howToUse: template.howToUse
          }))
        );
    });
  }

  public ngOnDestroy(): void {
    this.routeSubscription.unsubscribe();
  }

  public copyToClipboard(value: string) {
    navigator.clipboard.writeText(value)
      .then(() => {
        this.copyLabel = 'Copied';
        setTimeout(() => {
          this.copyLabel = 'Copy';
        }, 1000);
      })
      .catch(e =>
        /* eslint-disable-next-line */
        console.log(e)
      );
  }

  public open(template: TemplateDetailsVm) {
    const regex = /modules\/[^/]+\/[^/]+/;
    const match = template.source.match(regex);
    const modulePath = match ? match[0] : '';

    if (!modulePath) {
      /* eslint-disable-next-line */
      console.error('Module path not found in source URL');
    } else {
      const component = this.modalService.open(ImportDialogComponent, { size: 'lg', centered: true }).componentInstance;
      component.name = template.name;
      component.modulePath = modulePath;
    }
  }

}
