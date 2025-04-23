import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';
import { RouterModule } from '@angular/router';

import { BreadcrumbItem } from './breadcrumb';

@Component({
  selector: 'mst-breadcrumb',
  imports: [CommonModule, RouterModule],
  templateUrl: './breadcrumb.component.html',
  styleUrl: './breadcrumb.component.scss',
  standalone: true
})
export class BreadcrumbComponent  {
  @Input()
  public breadcrumbs: BreadcrumbItem[] = [];
}